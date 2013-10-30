-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Cell Receive Interface
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2RxCell.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/18/2009
-------------------------------------------------------------------------------
-- Description:
-- Cell Receive interface module for the Pretty Good Protocol core. 
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/18/2009: created.
-- 11/23/2009: Renamed package.
-- 06/25/2010: Added payload size config as generic.
-------------------------------------------------------------------------------

LIBRARY ieee;
--USE work.ALL;
USE work.Pgp2CorePackage.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2RxCell is 
   generic (
      RxLaneCnt     : integer := 4; -- Number of receive lanes, 1-4
      EnShortCells  : integer := 1; -- Enable short non-EOF cells
      PayloadCntTop : integer := 7  -- Top bit for payload counter
   );
   port (

      -- System clock, reset & control
      pgpRxClk          : in  std_logic;                                 -- Master clock
      pgpRxReset        : in  std_logic;                                 -- Synchronous reset input

      -- Link flush
      pgpRxFlush        : in  std_logic;                                 -- Flush the link

      -- Link is ready
      pgpRxLinkReady    : in  std_logic;                                 -- Local side has link

      -- Cell Error, one pulse per error
      pgpRxCellError    : out std_logic;                                 -- A cell error has occured

      -- Interface to PHY Logic
      cellRxPause       : in  std_logic;                                 -- Cell data pause
      cellRxSOC         : in  std_logic;                                 -- Cell data start of cell
      cellRxSOF         : in  std_logic;                                 -- Cell data start of frame
      cellRxEOC         : in  std_logic;                                 -- Cell data end of cell
      cellRxEOF         : in  std_logic;                                 -- Cell data end of frame
      cellRxEOFE        : in  std_logic;                                 -- Cell data end of frame error
      cellRxData        : in  std_logic_vector(RxLaneCnt*16-1 downto 0); -- Cell data data

      -- Common Frame Receive Interface For All VCs
      vcFrameRxSOF      : out std_logic;                                 -- PGP frame data start of frame
      vcFrameRxEOF      : out std_logic;                                 -- PGP frame data end of frame
      vcFrameRxEOFE     : out std_logic;                                 -- PGP frame data error
      vcFrameRxData     : out std_logic_vector(RxLaneCnt*16-1 downto 0); -- PGP frame data

      -- Frame Receive Interface, VC 0
      vc0FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
      vc0RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
      vc0RemBuffFull    : out std_logic;                                 -- Remote buffer full

      -- Frame Receive Interface, VC 1
      vc1FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
      vc1RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
      vc1RemBuffFull    : out std_logic;                                 -- Remote buffer full

      -- Frame Receive Interface, VC 2
      vc2FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
      vc2RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
      vc2RemBuffFull    : out std_logic;                                 -- Remote buffer full

      -- Frame Receive Interface, VC 3
      vc3FrameRxValid   : out std_logic;                                 -- PGP frame data is valid
      vc3RemBuffAFull   : out std_logic;                                 -- Remote buffer almost full
      vc3RemBuffFull    : out std_logic;                                 -- Remote buffer full

      -- Receive CRC Interface
      crcRxIn           : out std_logic_vector(RxLaneCnt*16-1 downto 0); -- Receive data for CRC
      crcRxWidth        : out std_logic;                                 -- Receive CRC width, 1=full, 0=32-bit
      crcRxInit         : out std_logic;                                 -- Receive CRC value init
      crcRxValid        : out std_logic;                                 -- Receive data for CRC is valid
      crcRxOut          : in  std_logic_vector(31 downto 0)              -- Receive calculated CRC value
   );

end Pgp2RxCell;


-- Define architecture
architecture Pgp2RxCell of Pgp2RxCell is

   -- Local Signals
   signal dly0SOC           : std_logic;
   signal dly0SOF           : std_logic;
   signal dly0EOC           : std_logic;
   signal dly0EOF           : std_logic;
   signal dly0EOFE          : std_logic;
   signal dly0Data          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal dly1SOC           : std_logic;
   signal dly1SOF           : std_logic;
   signal dly1EOC           : std_logic;
   signal dly1EOF           : std_logic;
   signal dly1EOFE          : std_logic;
   signal dly1Data          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal dly2SOC           : std_logic;
   signal dly2SOF           : std_logic;
   signal dly2EOC           : std_logic;
   signal dly2EOF           : std_logic;
   signal dly2EOFE          : std_logic;
   signal dly2Data          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal dly3SOC           : std_logic;
   signal dly3SOF           : std_logic;
   signal dly3EOC           : std_logic;
   signal dly3EOF           : std_logic;
   signal dly3EOFE          : std_logic;
   signal dly3Data          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal dly4SOC           : std_logic;
   signal dly4SOF           : std_logic;
   signal dly4EOC           : std_logic;
   signal dly4EOF           : std_logic;
   signal dly4EOFE          : std_logic;
   signal dly4Data          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal dly5SOC           : std_logic;
   signal dly5SOF           : std_logic;
   signal dly5EOC           : std_logic;
   signal dly5EOF           : std_logic;
   signal dly5EOFE          : std_logic;
   signal dly5Data          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal dly6SOC           : std_logic;
   signal dly6SOF           : std_logic;
   signal dly6EOC           : std_logic;
   signal dly6EOF           : std_logic;
   signal dly6EOFE          : std_logic;
   signal dly6Data          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal dly7SOC           : std_logic;
   signal dly7SOF           : std_logic;
   signal dly7EOC           : std_logic;
   signal dly7EOF           : std_logic;
   signal dly7EOFE          : std_logic;
   signal dly7Data          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal intCrcRxValid     : std_logic;
   signal crcNotZero        : std_logic;
   signal linkDownCnt       : std_logic_vector(4 downto 0);
   signal compSOC           : std_logic;
   signal compData          : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal detSOC            : std_logic;
   signal detSOF            : std_logic;
   signal outData           : std_logic_vector(RxLaneCnt*16-1 downto 0);
   signal detEOC            : std_logic;
   signal detEOF            : std_logic;
   signal detEOFE           : std_logic;
   signal inCellEn          : std_logic;
   signal nxtCellEn         : std_logic;
   signal inCellSerErr      : std_logic;
   signal inCellSOF         : std_logic;
   signal inCellEOC         : std_logic;
   signal inCellEOF         : std_logic;
   signal inCellEOFE        : std_logic;
   signal inCellCnt         : std_logic_vector(PayloadCntTop downto 0);
   signal vcInFrame         : std_logic_vector(3 downto 0);
   signal currVc            : std_logic_vector(1 downto 0);
   signal serErr            : std_logic;
   signal vc0Serial         : std_logic_vector(5 downto 0);
   signal vc0Valid          : std_logic;
   signal vc1Serial         : std_logic_vector(5 downto 0);
   signal vc1Valid          : std_logic;
   signal vc2Serial         : std_logic_vector(5 downto 0);
   signal vc2Valid          : std_logic;
   signal vc3Serial         : std_logic_vector(5 downto 0);
   signal vc3Valid          : std_logic;
   signal abortVc           : std_logic_vector(1 downto 0);
   signal abortEn           : std_logic;
   signal intCellError      : std_logic;
   signal dlyCellError      : std_logic;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Delay stages to line up data with CRC calculation
   process ( pgpRxClk, pgpRxReset ) begin
      if pgpRxReset = '1' then
         dly0SOC       <= '0'           after tpd;
         dly0SOF       <= '0'           after tpd;
         dly0EOC       <= '0'           after tpd;
         dly0EOF       <= '0'           after tpd;
         dly0EOFE      <= '0'           after tpd;
         dly0Data      <= (others=>'0') after tpd;
         dly1SOC       <= '0'           after tpd;
         dly1SOF       <= '0'           after tpd;
         dly1EOC       <= '0'           after tpd;
         dly1EOF       <= '0'           after tpd;
         dly1EOFE      <= '0'           after tpd;
         dly1Data      <= (others=>'0') after tpd;
         dly2SOC       <= '0'           after tpd;
         dly2SOF       <= '0'           after tpd;
         dly2EOC       <= '0'           after tpd;
         dly2EOF       <= '0'           after tpd;
         dly2EOFE      <= '0'           after tpd;
         dly2Data      <= (others=>'0') after tpd;
         dly3SOC       <= '0'           after tpd;
         dly3SOF       <= '0'           after tpd;
         dly3EOC       <= '0'           after tpd;
         dly3EOF       <= '0'           after tpd;
         dly3EOFE      <= '0'           after tpd;
         dly3Data      <= (others=>'0') after tpd;
         dly4SOC       <= '0'           after tpd;
         dly4SOF       <= '0'           after tpd;
         dly4EOC       <= '0'           after tpd;
         dly4EOF       <= '0'           after tpd;
         dly4EOFE      <= '0'           after tpd;
         dly4Data      <= (others=>'0') after tpd;
         dly5SOC       <= '0'           after tpd;
         dly5SOF       <= '0'           after tpd;
         dly5EOC       <= '0'           after tpd;
         dly5EOF       <= '0'           after tpd;
         dly5EOFE      <= '0'           after tpd;
         dly5Data      <= (others=>'0') after tpd;
         dly6SOC       <= '0'           after tpd;
         dly6SOF       <= '0'           after tpd;
         dly6EOC       <= '0'           after tpd;
         dly6EOF       <= '0'           after tpd;
         dly6EOFE      <= '0'           after tpd;
         dly6Data      <= (others=>'0') after tpd;
         dly7SOC       <= '0'           after tpd;
         dly7SOF       <= '0'           after tpd;
         dly7EOC       <= '0'           after tpd;
         dly7EOF       <= '0'           after tpd;
         dly7EOFE      <= '0'           after tpd;
         dly7Data      <= (others=>'0') after tpd;
         intCrcRxValid <= '0'           after tpd;
      elsif rising_edge(pgpRxClk) then

         -- Shift when not paused
         if cellRxPause = '0' then 

            -- Delay stage 0
            dly0SOC   <= cellRxSOC    after tpd;
            dly0SOF   <= cellRxSOF    after tpd;
            dly0EOC   <= cellRxEOC    after tpd;
            dly0EOF   <= cellRxEOF    after tpd;
            dly0EOFE  <= cellRxEOFE   after tpd;
            dly0Data  <= cellRxData   after tpd;

            -- Delay stage 1
            dly1SOC   <= dly0SOC     after tpd;
            dly1SOF   <= dly0SOF     after tpd;
            dly1EOC   <= dly0EOC     after tpd;
            dly1EOF   <= dly0EOF     after tpd;
            dly1EOFE  <= dly0EOFE    after tpd;
            dly1Data  <= dly0Data    after tpd;
           
            -- Delay stage 2
            dly2SOC   <= dly1SOC     after tpd;
            dly2SOF   <= dly1SOF     after tpd;
            dly2EOC   <= dly1EOC     after tpd;
            dly2EOF   <= dly1EOF     after tpd;
            dly2EOFE  <= dly1EOFE    after tpd;
            dly2Data  <= dly1Data    after tpd;

            -- Delay stage 3
            dly3SOC   <= dly2SOC     after tpd;
            dly3SOF   <= dly2SOF     after tpd;
            dly3EOC   <= dly2EOC     after tpd;
            dly3EOF   <= dly2EOF     after tpd;
            dly3EOFE  <= dly2EOFE    after tpd;
            dly3Data  <= dly2Data    after tpd;

            -- Delay stage 4
            dly4SOC   <= dly3SOC     after tpd;
            dly4SOF   <= dly3SOF     after tpd;
            dly4EOC   <= dly3EOC     after tpd;
            dly4EOF   <= dly3EOF     after tpd;
            dly4EOFE  <= dly3EOFE    after tpd;
            dly4Data  <= dly3Data    after tpd;

            -- Delay stage 5
            dly5SOC   <= dly4SOC     after tpd;
            dly5SOF   <= dly4SOF     after tpd;
            dly5EOC   <= dly4EOC     after tpd;
            dly5EOF   <= dly4EOF     after tpd;
            dly5EOFE  <= dly4EOFE    after tpd;
            dly5Data  <= dly4Data    after tpd;

            -- Delay stage 6
            dly6SOC   <= dly5SOC     after tpd;
            dly6SOF   <= dly5SOF     after tpd;
            dly6EOC   <= dly5EOC     after tpd;
            dly6EOF   <= dly5EOF     after tpd;
            dly6EOFE  <= dly5EOFE    after tpd;
            dly6Data  <= dly5Data    after tpd;

            -- Delay stage 7
            dly7SOC   <= dly6SOC     after tpd;
            dly7SOF   <= dly6SOF     after tpd;
            dly7EOC   <= dly6EOC     after tpd;
            dly7EOF   <= dly6EOF     after tpd;
            dly7EOFE  <= dly6EOFE    after tpd;
            dly7Data  <= dly6Data    after tpd;

            -- CRC Enable & partial flag
            if cellRxSOC = '1' then
              intCrcRxValid <= '1' after tpd;
            elsif cellRxEOC = '1' then
              intCrcRxValid <= '0' after tpd;
            end if;
         end if;
      end if;
   end process;


   -- CRC Data Output, SOC field overwritten with zeros
   GEN_CRC: for i in 0 to (RxLaneCnt-1) generate
      process ( dly0SOC, dly0Data ) begin
         if dly0SOC = '1' then
            crcRxIn(i*16+7 downto i*16) <= (others=>'0');
         else 
            crcRxIn(i*16+7 downto i*16) <= dly0Data(i*16+7 downto i*16);
         end if;
         crcRxIn(i*16+15 downto i*16+8) <= dly0Data(i*16+15 downto i*16+8);
      end process;
   end generate;


   -- Output to CRC engine
   crcRxWidth   <= '0' when ( cellRxEOC = '1' and RxLaneCnt > 2 ) else '1';
   crcRxInit    <= dly0SOC;
   crcRxValid   <= intCrcRxValid and not cellRxPause;


   -- Choose tap positions in delay chain

   -- Serial number compare position, detSOC - 1
   compSOC  <= dly6SOC;
   compData <= dly6Data;

   -- SOC detect position, 
   detSOC   <= dly7SOC;
   detSOF   <= dly7SOF;
   outData  <= dly7Data;

   -- EOC detect position, depends on lane count
   -- detSOC - 4 when 1 lane, detSOC - 3 when multiple lanes
   detEOC   <= dly3EOC  when RxLaneCnt = 1 else dly4EOC;
   detEOF   <= dly3EOF  when RxLaneCnt = 1 else dly4EOF;
   detEOFE  <= dly3EOFE when RxLaneCnt = 1 else dly4EOFE;


   -- Detect current VC, check cell serial number
   process ( pgpRxClk, pgpRxReset ) begin
      if pgpRxReset = '1' then
         currVc    <= (others=>'0') after tpd;
         serErr    <= '0'           after tpd;
         vc0Serial <= (others=>'0') after tpd;
         vc0Valid  <= '0'           after tpd;
         vc1Serial <= (others=>'0') after tpd;
         vc1Valid  <= '0'           after tpd;
         vc2Serial <= (others=>'0') after tpd;
         vc2Valid  <= '0'           after tpd;
         vc3Serial <= (others=>'0') after tpd;
         vc3Valid  <= '0'           after tpd;
      elsif rising_edge(pgpRxClk) then

         -- Link is down, init counts
         if pgpRxLinkReady = '0' then
            currVc    <= (others=>'0') after tpd;
            serErr    <= '0'           after tpd;
            vc0Serial <= (others=>'0') after tpd;
            vc0Valid  <= '0'           after tpd;
            vc1Serial <= (others=>'0') after tpd;
            vc1Valid  <= '0'           after tpd;
            vc2Serial <= (others=>'0') after tpd;
            vc2Valid  <= '0'           after tpd;
            vc3Serial <= (others=>'0') after tpd;
            vc3Valid  <= '0'           after tpd;

         -- Pipeline enable
         elsif cellRxPause = '0' then

            -- SOC for compare
            if compSOC = '1' then 

               -- Register VC value
               currVc <= compData(15 downto 14) after tpd;

               -- Compare current count, store current count for future increment
               case compData(15 downto 14) is

                  -- VC 0
                  when "00" => 
                     if compData(13 downto 8) = vc0Serial then 
                        serErr <= '0' after tpd; 
                     else 
                        vc0Serial <= compData(13 downto 8) after tpd;
                        serErr    <= vc0Valid              after tpd;
                     end if;
                     vc0Valid <= '1' after tpd;

                  -- VC 1
                  when "01" =>
                     if compData(13 downto 8) = vc1Serial then 
                        serErr <= '0' after tpd; 
                     else 
                        vc1Serial <= compData(13 downto 8) after tpd;
                        serErr    <= vc1Valid              after tpd;
                     end if;
                     vc1Valid <= '1' after tpd;

                  -- VC 2
                  when "10" =>
                     if compData(13 downto 8) = vc2Serial then 
                        serErr <= '0' after tpd; 
                     else 
                        vc2Serial <= compData(13 downto 8) after tpd;
                        serErr    <= vc2Valid              after tpd;
                     end if;
                     vc2Valid <= '1' after tpd;

                  -- VC 3
                  when others =>
                     if compData(13 downto 8) = vc3Serial then 
                        serErr <= '0' after tpd; 
                     else 
                        vc3Serial <= compData(13 downto 8) after tpd;
                        serErr    <= vc3Valid              after tpd;
                     end if;
                     vc3Valid <= '1' after tpd;
               end case;

            -- SOC for increment
            elsif detSOC = '1' then 
               case currVc is
                  when "00"   => vc0Serial <= vc0Serial + 1 after tpd;
                  when "01"   => vc1Serial <= vc1Serial + 1 after tpd;
                  when "10"   => vc2Serial <= vc2Serial + 1 after tpd;
                  when others => vc3Serial <= vc3Serial + 1 after tpd;
               end case;
            end if;
         end if;
      end if;
   end process;


   -- Receive cell tracking
   process ( pgpRxClk, pgpRxReset ) begin
      if pgpRxReset = '1' then
         crcNotZero        <= '0'           after tpd;
         linkDownCnt       <= (others=>'0') after tpd;
         inCellEn          <= '0'           after tpd;
         inCellSerErr      <= '0'           after tpd;
         inCellSOF         <= '0'           after tpd;
         inCellEOC         <= '0'           after tpd;
         inCellEOF         <= '0'           after tpd;
         inCellEOFE        <= '0'           after tpd;
         inCellCnt         <= (others=>'0') after tpd;
         abortEn           <= '0'           after tpd;
         abortVc           <= (others=>'0') after tpd;
         intCellError      <= '0'           after tpd;
         dlyCellError      <= '0'           after tpd;
         pgpRxCellError    <= '0'           after tpd;
         vcInFrame         <= (others=>'0') after tpd;
      elsif rising_edge(pgpRxClk) then

         -- Cell error edge generation
         dlyCellError   <= intCellError after tpd;
         pgpRxCellError <= intCellError and not dlyCellError after tpd;

         -- CRC Error
         if crcRxOut = 0 then 
            crcNotZero <= '0' after tpd;
         else
            crcNotZero <= '1' after tpd;
         end if;

         -- Link down counter
         if pgpRxLinkReady = '1' then
            linkDownCnt <= (others=>'0') after tpd;
         elsif linkDownCnt(4) = '0' then
            linkDownCnt <= linkDownCnt + 1 after tpd;
         end if;

         -- Count size of each cell received
         if cellRxPause = '0' then
            if inCellEn = '1' then
               inCellCnt <= inCellCnt - 1 after tpd;
            else
               inCellCnt <= (others=>'1') after tpd;
            end if;
         end if;

         -- Link is down. Terminate transmission for any active VCs
         if pgpRxLinkReady = '0' then

            -- Enabled every 4 clocks to ensure proper spacing between generated EOFs
            if linkDownCnt(1 downto 0) = "11" then

               -- VC is active 
               if vcInFrame(conv_integer(linkDownCnt(3 downto 2))) = '1' then
                  abortEn <= '1' after tpd;
                  vcInFrame(conv_integer(linkDownCnt(3 downto 2))) <= '0' after tpd;
               else
                  abortEn <= '0' after tpd;
               end if;
            else
               abortEn <= '0' after tpd;
            end if;

            -- VC for abort
            abortVc <= linkDownCnt(3 downto 2) after tpd;

            -- Clear cell control signals
            inCellEn     <= '0' after tpd;
            inCellSerErr <= '0' after tpd;
            inCellSOF    <= '0' after tpd;
            inCellEOC    <= '0' after tpd;
            inCellEOF    <= '0' after tpd;
            inCellEOFE   <= '0' after tpd;
            intCellError <= '0' after tpd;

         -- Link is ready
         else 

            -- Clear abort flags
            abortVc <= (others=>'0') after tpd;
            abortEn <= '0'           after tpd;

            -- Link flush set
            if pgpRxFlush = '1' then
               vcInFrame <= (others=>'0') after tpd;

            -- Pipeline enable
            elsif cellRxPause = '0' then

               -- SOC Received
               if detSOC = '1' then

                  -- Do we output data and mark in frame?
                  -- Yes if SOF is set and serial number is ok 
                  -- Yes if already in frame
                  if nxtCellEn = '1' then
                     inCellEn                        <= '1' after tpd;
                     vcInFrame(conv_integer(currVc)) <= '1' after tpd;
                  end if;

                  -- Do we mark output as SOF?
                  -- Yes if SOF is seen and the serial number is ok and we are not already in frame
                  if detSOF = '1' and serErr = '0' and vcInFrame(conv_integer(currVc)) = '0' then
                     inCellSOF <= '1' after tpd;
                  end if;

                  -- Do we mark serial error flag?
                  -- Yes if SOF is set and we are already in frame
                  -- Yes if serial number error
                  if (detSOF = '1' and vcInFrame(conv_integer(currVc)) = '1') or serErr = '1' then
                     inCellSerErr <= '1' after tpd;
                  end if;
               
               -- Mark out of cell after EOC 
               elsif inCellEOC = '1' then
                  inCellEn     <= '0' after tpd;
                  inCellSerErr <= '0' after tpd;
                  inCellSOF    <= '0' after tpd;

                  -- Clear frame state if EOF
                  if inCellEOF = '1' then
                     vcInFrame(conv_integer(currVc)) <= '0' after tpd;
                  end if;

               -- Clear SOF
               else
                  inCellSOF <= '0' after tpd;
               end if;

               -- End of cell, check for short cell case
               if detEOC = '1' and (inCellEn = '1' or nxtCellEn = '1') then
                  inCellEOC    <= '1'                                   after tpd;
                  intCellError <= inCellSerErr or crcNotZero            after tpd;

                  -- Cell is too short
                  if detEOF = '0' and inCellCnt /= 1 and EnShortCells = 0 then
                     inCellEOF    <= '1' after tpd;
                     inCellEOFE   <= '1' after tpd;
                     intCellError <= '1' after tpd;
                  else
                     inCellEOF    <= detEOF  or inCellSerErr or crcNotZero after tpd;
                     inCellEOFE   <= detEOFE or inCellSerErr or crcNotZero after tpd;
                     intCellError <= inCellSerErr or crcNotZero            after tpd;
                  end if;

               -- Cell might be too long
               elsif inCellEn = '1' and inCellCnt = 0 and inCellEOC = '0' then
                  inCellEOC    <= '1' after tpd;
                  inCellEOF    <= '1' after tpd;
                  inCellEOFE   <= '1' after tpd;
                  intCellError <= '1' after tpd;
               else
                  inCellEOC    <= '0' after tpd;
                  inCellEOF    <= '0' after tpd;
                  inCellEOFE   <= '0' after tpd;
                  intCellError <= '0' after tpd;
               end if;
            end if;
         end if;
      end if;
   end process;


   -- Do we output data and mark in frame?
   -- Yes if SOF is set and serial number is ok 
   -- Yes if already in frame
   nxtCellEn <= '1' when ((detSOF = '1' and serErr = '0') or vcInFrame(conv_integer(currVc)) = '1') else '0'; 


   -- Data Output
   process ( pgpRxClk, pgpRxReset ) begin
      if pgpRxReset = '1' then
         vcFrameRxData   <= (others=>'0') after tpd;
         vcFrameRxSOF    <= '0'           after tpd;
         vcFrameRxEOF    <= '0'           after tpd;
         vcFrameRxEOFE   <= '0'           after tpd;
         vc0FrameRxValid <= '0'           after tpd;
         vc1FrameRxValid <= '0'           after tpd;
         vc2FrameRxValid <= '0'           after tpd;
         vc3FrameRxValid <= '0'           after tpd;
      elsif rising_edge(pgpRxClk) then

         -- Data abort is enabled
         if abortEn = '1' then
            case abortVc is
               when "00" =>
                  vc0FrameRxValid <= '1' after tpd;
                  vc1FrameRxValid <= '0' after tpd;
                  vc2FrameRxValid <= '0' after tpd;
                  vc3FrameRxValid <= '0' after tpd;
               when "01" =>
                  vc0FrameRxValid <= '0' after tpd;
                  vc1FrameRxValid <= '1' after tpd;
                  vc2FrameRxValid <= '0' after tpd;
                  vc3FrameRxValid <= '0' after tpd;
               when "10" =>
                  vc0FrameRxValid <= '0' after tpd;
                  vc1FrameRxValid <= '0' after tpd;
                  vc2FrameRxValid <= '1' after tpd;
                  vc3FrameRxValid <= '0' after tpd;
               when others =>
                  vc0FrameRxValid <= '0' after tpd;
                  vc1FrameRxValid <= '0' after tpd;
                  vc2FrameRxValid <= '0' after tpd;
                  vc3FrameRxValid <= '1' after tpd;
            end case;

            -- Abort output
            vcFrameRxSOF   <= '0' after tpd;
            vcFrameRxEOF   <= '1' after tpd;
            vcFrameRxEOFE  <= '1' after tpd;

         -- Pipeline is enabled
         elsif cellRxPause = '0' and inCellEn = '1' then
            case currVc is
               when "00" =>
                  vc0FrameRxValid <= '1' after tpd;
                  vc1FrameRxValid <= '0' after tpd;
                  vc2FrameRxValid <= '0' after tpd;
                  vc3FrameRxValid <= '0' after tpd;
               when "01" =>
                  vc0FrameRxValid <= '0' after tpd;
                  vc1FrameRxValid <= '1' after tpd;
                  vc2FrameRxValid <= '0' after tpd;
                  vc3FrameRxValid <= '0' after tpd;
               when "10" =>
                  vc0FrameRxValid <= '0' after tpd;
                  vc1FrameRxValid <= '0' after tpd;
                  vc2FrameRxValid <= '1' after tpd;
                  vc3FrameRxValid <= '0' after tpd;
               when others =>
                  vc0FrameRxValid <= '0' after tpd;
                  vc1FrameRxValid <= '0' after tpd;
                  vc2FrameRxValid <= '0' after tpd;
                  vc3FrameRxValid <= '1' after tpd;
            end case;

            -- Data output
            vcFrameRxData  <= outData    after tpd;
            vcFrameRxSOF   <= inCellSOF  after tpd;
            vcFrameRxEOF   <= inCellEOF  after tpd;
            vcFrameRxEOFE  <= inCellEOFE after tpd;

         -- Paused or no data
         else 
            vc0FrameRxValid <= '0' after tpd;
            vc1FrameRxValid <= '0' after tpd;
            vc2FrameRxValid <= '0' after tpd;
            vc3FrameRxValid <= '0' after tpd;
         end if;
      end if;
   end process;


   -- Update buffer status on successfull cell reception
   process ( pgpRxClk, pgpRxReset ) begin
      if pgpRxReset = '1' then
         vc0RemBuffAFull <= '1' after tpd;
         vc0RemBuffFull  <= '1' after tpd;
         vc1RemBuffAFull <= '1' after tpd;
         vc1RemBuffFull  <= '1' after tpd;
         vc2RemBuffAFull <= '1' after tpd;
         vc2RemBuffFull  <= '1' after tpd;
         vc3RemBuffAFull <= '1' after tpd;
         vc3RemBuffFull  <= '1' after tpd;
      elsif rising_edge(pgpRxClk) then

         -- Link is not ready, force buffer states to bad
         if pgpRxLinkReady = '0' then
            vc0RemBuffAFull <= '1' after tpd;
            vc0RemBuffFull  <= '1' after tpd;
            vc1RemBuffAFull <= '1' after tpd;
            vc1RemBuffFull  <= '1' after tpd;
            vc2RemBuffAFull <= '1' after tpd;
            vc2RemBuffFull  <= '1' after tpd;
            vc3RemBuffAFull <= '1' after tpd;
            vc3RemBuffFull  <= '1' after tpd;

         -- Update buffer status 
         elsif cellRxEOC = '1' then
            vc0RemBuffAFull <= cellRxData(8)  after tpd;
            vc0RemBuffFull  <= cellRxData(12) after tpd;
            vc1RemBuffAFull <= cellRxData(9)  after tpd;
            vc1RemBuffFull  <= cellRxData(13) after tpd;
            vc2RemBuffAFull <= cellRxData(10) after tpd;
            vc2RemBuffFull  <= cellRxData(14) after tpd;
            vc3RemBuffAFull <= cellRxData(11) after tpd;
            vc3RemBuffFull  <= cellRxData(15) after tpd;
         end if;
      end if;
   end process;

end Pgp2RxCell;

