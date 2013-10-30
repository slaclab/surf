---------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol V2, Physical Interface Transmit Module
-- Project       : General Purpose Core
---------------------------------------------------------------------------------
-- File          : Pgp2TxPhy.vhd
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
---------------------------------------------------------------------------------

LIBRARY ieee;
--USE work.ALL;
USE work.Pgp2CorePackage.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2TxPhy is 
   generic (
      TxLaneCnt : integer  := 4  -- Number of receive lanes, 1-4
   );
   port ( 

      -- System clock, reset & control
      pgpTxClk          : in  std_logic;                                 -- Master clock
      pgpTxReset        : in  std_logic;                                 -- Synchronous reset input

      -- Link is ready
      pgpTxLinkReady    : out std_logic;                                 -- Local side has link

      -- Opcode Transmit Interface
      pgpTxOpCodeEn     : in  std_logic;                                 -- Opcode receive enable
      pgpTxOpCode       : in  std_logic_vector(7 downto 0);              -- Opcode receive value

      -- Sideband data
      pgpLocLinkReady   : in  std_logic;                                 -- Far end side has link
      pgpLocData        : in  std_logic_vector(7 downto 0);              -- Far end side User Data

      -- Cell Transmit Interface
      cellTxSOC         : in  std_logic;                                 -- Cell data start of cell
      cellTxSOF         : in  std_logic;                                 -- Cell data start of frame
      cellTxEOC         : in  std_logic;                                 -- Cell data end of cell
      cellTxEOF         : in  std_logic;                                 -- Cell data end of frame
      cellTxEOFE        : in  std_logic;                                 -- Cell data end of frame error
      cellTxData        : in  std_logic_vector(TxLaneCnt*16-1 downto 0); -- Cell data data

      -- Physical Interface Signals
      phyTxData         : out std_logic_vector(TxLaneCnt*16-1 downto 0); -- PHY receive data
      phyTxDataK        : out std_logic_vector(TxLaneCnt*2-1  downto 0); -- PHY receive data is K character
      phyTxReady        : in  std_logic;                                 -- PHY receive interface is ready

      -- Debug
      debug             : out std_logic_vector(63 downto 0)
   ); 

end Pgp2TxPhy;


-- Define architecture
architecture Pgp2TxPhy of Pgp2TxPhy is

   -- Local Signals
   signal algnCnt        : std_logic_vector(6 downto 0);
   signal algnCntRst     : std_logic;
   signal intTxLinkReady : std_logic;
   signal nxtTxLinkReady : std_logic;
   signal nxtTxData      : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal nxtTxDataK     : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal dlyTxData      : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal dlyTxDataK     : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal dlySelect      : std_logic;
   signal intTxData      : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal intTxDataK     : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal intTxOpCode    : std_logic_vector(7 downto 0);
   signal intTxOpCodeEn  : std_logic;
   signal skpAData       : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal skpADataK      : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal skpBData       : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal skpBDataK      : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal alnAData       : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal alnADataK      : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal alnBData       : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal alnBDataK      : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal ltsAData       : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal ltsADataK      : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal ltsBData       : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal ltsBDataK      : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal cellData       : std_logic_vector(TxLaneCnt*16-1 downto 0);
   signal cellDataK      : std_logic_vector(TxLaneCnt*2-1  downto 0);
   signal dlyTxEOC       : std_logic;

   -- Physical Link State
   constant ST_LOCK  : std_logic_vector(3 downto 0) := "0000";
   constant ST_SKP_A : std_logic_vector(3 downto 0) := "0001";
   constant ST_SKP_B : std_logic_vector(3 downto 0) := "0010";
   constant ST_LTS_A : std_logic_vector(3 downto 0) := "0011";
   constant ST_LTS_B : std_logic_vector(3 downto 0) := "0100";
   constant ST_ALN_A : std_logic_vector(3 downto 0) := "0101";
   constant ST_ALN_B : std_logic_vector(3 downto 0) := "0110";
   constant ST_CELL  : std_logic_vector(3 downto 0) := "0111";
   constant ST_EMPTY : std_logic_vector(3 downto 0) := "1000";
   signal   curState : std_logic_vector(3 downto 0);
   signal   nxtState : std_logic_vector(3 downto 0);

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Link status
   pgpTxLinkReady <= intTxLinkReady;

   -- State transition sync logic. 
   process ( pgpTxClk, pgpTxReset ) begin
      if pgpTxReset = '1' then
         curState         <= ST_LOCK       after tpd;
         algnCnt          <= (others=>'0') after tpd;
         intTxLinkReady   <= '0'           after tpd;
         intTxOpCode      <= (others=>'0') after tpd;
         intTxOpCodeEn    <= '0'           after tpd;
      elsif rising_edge(pgpTxClk) then

         -- Opcode Transmit
         if pgpTxOpCodeEn = '1' then
            intTxOpCode <= pgpTxOpCode after tpd;
         end if;
         intTxOpCodeEn <= pgpTxOpCodeEn after tpd;

         -- Status signal
         intTxLinkReady <= nxtTxLinkReady after tpd;

         -- PLL Lock is lost
         if phyTxReady = '0' then
            curState   <= ST_LOCK       after tpd;
         else
            curState <= nxtState after tpd;
         end if;

         -- Cell Counter
         if algnCntRst = '1' then
            algnCnt <= (others=>'1') after tpd;
         elsif algnCnt /= 0 and cellTxEOC = '1' then
            algnCnt <= algnCnt - 1 after tpd;
         end if;
      end if;
   end process;


   -- Link control state machine
   process ( curState, intTxLinkReady, cellTxEOC, algnCnt,
             skpAData, skpADataK, skpBData, skpBDataK, alnAData, alnADataK, alnBData,
             alnBDataK, ltsAData, ltsADataK, ltsBData, ltsBDataK, cellData, cellDataK ) begin
      case curState is 

         -- Wait for lock state
         when ST_LOCK =>
            algnCntRst     <= '1';
            nxtTxLinkReady <= '0';
            nxtTxData      <= (others=>'0');
            nxtTxDataK     <= (others=>'0');
            nxtState       <= ST_SKP_A;

         -- Transmit SKIP word A
         when ST_SKP_A => 
            nxtTxData      <= skpAData;
            nxtTxDataK     <= skpADataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_SKP_B;

         -- Transmit SKIP word B
         when ST_SKP_B => 
            nxtTxData      <= skpBData;
            nxtTxDataK     <= skpBDataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_LTS_A;

         -- Transmit Align word A
         when ST_ALN_A => 
            nxtTxData      <= alnAData;
            nxtTxDataK     <= alnADataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_ALN_B;

         -- Transmit Align word B
         when ST_ALN_B => 
            nxtTxData      <= alnBData;
            nxtTxDataK     <= alnBDataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_LTS_A;

         -- Transmit Link Training word A
         when ST_LTS_A => 
            nxtTxData      <= ltsAData;
            nxtTxDataK     <= ltsADataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= intTxLinkReady;
            nxtState       <= ST_LTS_B;

         -- Transmit Link Training word B
         when ST_LTS_B => 
            nxtTxData      <= ltsBData;
            nxtTxDataK     <= ltsBDataK;
            algnCntRst     <= '0';
            nxtTxLinkReady <= '1';
            nxtState       <= ST_CELL;

         -- Transmit Cell Data
         when ST_CELL => 
            nxtTxLinkReady <= '1';
            nxtTxData      <= cellData;
            nxtTxDataK     <= cellDataK;
            algnCntRst     <= '0';

            -- State transition
            if cellTxEOC = '1' then
               nxtState   <= ST_EMPTY;
            else
               nxtState   <= curState;
            end if;

         -- Empty location, used to re-adjust delay pipeline
         when ST_EMPTY => 
            nxtTxLinkReady <= '1';
            nxtTxData      <= (others=>'0');
            nxtTxDataK     <= (others=>'0');

            -- After enough cells send alignment word
            if algnCnt = 0 then
               algnCntRst <= '1';
               nxtState   <= ST_ALN_A;
            else
               algnCntRst <= '0';
               nxtState   <= ST_SKP_A;
            end if;

         -- Default state
         when others =>
            algnCntRst     <= '0';
            nxtTxLinkReady <= '0';
            nxtTxData      <= (others=>'0');
            nxtTxDataK     <= (others=>'0');
            nxtState       <= ST_LOCK;
      end case;
   end process;


   -- Generate Data
   GEN_DATA: for i in 0 to (TxLaneCnt-1) generate

      -- Skip word A
      skpAData(i*16+7  downto i*16)   <= K_COM;
      skpADataK(i*2)                  <= '1';
      skpAData(i*16+15 downto i*16+8) <= K_SKP;
      skpADataK(i*2+1)                <= '1';

      -- Skip word B
      skpBData(i*16+7  downto i*16)   <= K_SKP;
      skpBDataK(i*2)                  <= '1';
      skpBData(i*16+15 downto i*16+8) <= K_SKP;
      skpBDataK(i*2+1)                <= '1';

      -- Alignment Word A
      alnAData(i*16+7  downto i*16)   <= K_COM;
      alnADataK(i*2)                  <= '1';
      alnAData(i*16+15 downto i*16+8) <= K_ALN;
      alnADataK(i*2+1)                <= '1';

      -- Alignment Word B
      alnBData(i*16+7  downto i*16)   <= K_ALN;
      alnBDataK(i*2)                  <= '1';
      alnBData(i*16+15 downto i*16+8) <= K_ALN;
      alnBDataK(i*2+1)                <= '1';

      -- Link Training Word A
      ltsAData(i*16+7  downto i*16)   <= K_LTS;
      ltsADataK(i*2)                  <= '1';
      ltsAData(i*16+15 downto i*16+8) <= D_102;
      ltsADataK(i*2+1)                <= '0';

      -- Link Training Word B
      ltsBData(i*16+7  downto i*16)    <= pgpLocData;
      ltsBDataK(i*2)                   <= '0';
      ltsBData(i*16+14)                <= '0'; -- Spare
      ltsBData(i*16+13 downto i*16+12) <= conv_std_logic_vector(TxLaneCnt-1,2);
      ltsBData(i*16+11 downto i*16+8)  <= pgp2Id;
      ltsBData(i*16+15)                <= pgpLocLinkReady;
      ltsBDataK(i*2+1)                 <= '0';

      -- Cell Data, lower byte
      cellData(i*16+7  downto i*16) <= K_SOF  when cellTxSOF  = '1' else
                                       K_SOC  when cellTxSOC  = '1' else
                                       K_EOFE when cellTxEOFE = '1' else
                                       K_EOF  when cellTxEOF  = '1' else
                                       K_EOC  when cellTxEOC  = '1' else
                                       cellTxData(i*16+7 downto i*16);

      -- Cell Data, upper byte
      cellData(i*16+15 downto i*16+8) <= cellTxData(i*16+15 downto i*16+8);

      -- Cell Data, lower control
      cellDataK(i*2) <= '1' when cellTxSOF = '1' or cellTxSOC = '1' or cellTxEOFE = '1' or 
                                 cellTxEOF = '1' or cellTxEOC = '1' else '0'; 

      -- Cell Data, upper control
      cellDataK(i*2+1) <= '0';
   end generate;


   -- Delay chain select, used when an opcode is transmitted.
   -- opcode will overwrite current position and delay chain will
   -- be selected until an EOC is transmitted. At that time the
   -- non-delayed chain will be select. An empty position is inserted
   -- after EOC so that valid opcodes are not lost.
   process ( pgpTxClk, pgpTxReset ) begin
      if pgpTxReset = '1' then
         dlySelect <= '0' after tpd;
         dlyTxEOC  <= '0' after tpd;
      elsif rising_edge(pgpTxClk) then

         -- Choose delay chain when opcode is transmitted
         if intTxOpCodeEn = '1' then
            dlySelect <= '1' after tpd;
        
         -- Reset delay chain when delayed EOC is transmitted
         elsif dlyTxEOC = '1' then
            dlySelect <= '0' after tpd;
         end if;

         -- Delayed copy of EOC
         dlyTxEOC <= cellTxEOC after tpd;

      end if;
   end process;


   -- Outgoing data
   GEN_OUT: for i in 0 to (TxLaneCnt-1) generate
      process ( pgpTxClk, pgpTxReset ) begin
         if pgpTxReset = '1' then
            intTxData(i*16+15 downto i*16) <= (others=>'0') after tpd;
            intTxDataK(i*2+1  downto i*2)  <= (others=>'0') after tpd;
            dlyTxData(i*16+15 downto i*16) <= (others=>'0') after tpd;
            dlyTxDataK(i*2+1  downto i*2)  <= (others=>'0') after tpd;
         elsif rising_edge(pgpTxClk) then

            -- Delayed copy of data
            dlyTxData(i*16+15 downto i*16) <= nxtTxData(i*16+15 downto i*16) after tpd;
            dlyTxDataK(i*2+1  downto i*2)  <= nxtTxDataK(i*2+1  downto i*2)  after tpd;

            -- PLL Lock is lost
            if phyTxReady = '0' then
               intTxData(i*16+15 downto i*16) <= (others=>'0') after tpd;
               intTxDataK(i*2+1  downto i*2)  <= (others=>'0') after tpd;
            else

               -- Delayed data, opcode transmission is not allowed until delay line resets
               if dlySelect = '1' then
                  intTxData(i*16+15 downto i*16) <= dlyTxData(i*16+15 downto i*16) after tpd;
                  intTxDataK(i*2+1  downto i*2)  <= dlyTxDataK(i*2+1  downto i*2)  after tpd;

               -- Transmit opcode
               elsif intTxOpCodeEn = '1' then
                  intTxData(i*16+7  downto i*16)   <= K_OTS       after tpd;
                  intTxDataK(i*2)                  <= '1'         after tpd;
                  intTxData(i*16+15 downto i*16+8) <= intTxOpCode after tpd;
                  intTxDataK(i*2+1)                <= '0'         after tpd;

               -- Nornal Data
               else 
                  intTxData(i*16+15 downto i*16) <= nxtTxData(i*16+15 downto i*16) after tpd;
                  intTxDataK(i*2+1  downto i*2)  <= nxtTxDataK(i*2+1  downto i*2)  after tpd;
               end if;
            end if;
         end if;
      end process;
   end generate;

   -- Outgoing data
   phyTxData  <= intTxData;
   phyTxDataK <= intTxDataK;

   -- Debug
   debug(63 downto 52) <= (others=>'0');
   debug(51)           <= cellTxSOC;
   debug(50)           <= cellTxSOF;
   debug(49)           <= cellTxEOF;
   debug(48)           <= cellTxEOFE;
   debug(47 downto 32) <= cellTxData(15 downto 0);
   debug(31)           <= dlySelect;
   debug(30)           <= dlyTxEOC;
   debug(29 downto 26) <= (others=>'0');
   debug(25 downto 24) <= intTxDataK(1  downto 0);
   debug(23 downto  8) <= intTxData(15 downto 0);
   debug(7)            <= '0';
   debug(6  downto  3) <= curState;
   debug(2)            <= pgpTxOpCodeEn;
   debug(1)            <= intTxOpCodeEn;
   debug(0)            <= cellTxEOC;

end Pgp2TxPhy;

