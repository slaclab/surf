-------------------------------------------------------------------------------
-- File       : Pgp2bRxCell.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2009-05-27
-- Last update: 2017-03-28
-------------------------------------------------------------------------------
-- Description:
-- Cell Receive interface module for the Pretty Good Protocol core. 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

LIBRARY ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;

entity Pgp2bRxCell is 
   generic (
      TPD_G             : time                 := 1 ns;
      RX_LANE_CNT_G     : integer range 1 to 2 := 1; -- Number of receive lanes, 1-2
      EN_SHORT_CELLS_G  : integer              := 1; -- Enable short non-EOF cells
      PAYLOAD_CNT_TOP_G : integer              := 7  -- Top bit for payload counter
   );
   port (

      -- System clock, reset & control
      pgpRxClkEn        : in  sl := '1';                        -- Master clock Enable
      pgpRxClk          : in  sl;                               -- Master clock
      pgpRxClkRst       : in  sl;                               -- Synchronous reset input

      -- Link flush
      pgpRxFlush        : in  sl;                               -- Flush the link

      -- Link is ready
      pgpRxLinkReady    : in  sl;                               -- Local side has link

      -- Cell Error, one pulse per error
      pgpRxCellError    : out sl;                               -- A cell error has occured

      -- Interface to PHY Logic
      cellRxPause       : in  sl;                               -- Cell data pause
      cellRxSOC         : in  sl;                               -- Cell data start of cell
      cellRxSOF         : in  sl;                               -- Cell data start of frame
      cellRxEOC         : in  sl;                               -- Cell data end of cell
      cellRxEOF         : in  sl;                               -- Cell data end of frame
      cellRxEOFE        : in  sl;                               -- Cell data end of frame error
      cellRxData        : in  slv(RX_LANE_CNT_G*16-1 downto 0); -- Cell data data

      -- Common Frame Receive Interface For All VCs
      vcFrameRxSOF      : out sl;                               -- PGP frame data start of frame
      vcFrameRxEOF      : out sl;                               -- PGP frame data end of frame
      vcFrameRxEOFE     : out sl;                               -- PGP frame data error
      vcFrameRxData     : out slv(RX_LANE_CNT_G*16-1 downto 0); -- PGP frame data

      -- Frame Receive Interface, VC 0
      vc0FrameRxValid   : out sl;                               -- PGP frame data is valid
      vc0RemAlmostFull  : out sl;                               -- Remote buffer almost full
      vc0RemOverflow    : out sl;                               -- Remote buffer overflow

      -- Frame Receive Interface, VC 1
      vc1FrameRxValid   : out sl;                               -- PGP frame data is valid
      vc1RemAlmostFull  : out sl;                               -- Remote buffer almost full
      vc1RemOverflow    : out sl;                               -- Remote buffer overflow

      -- Frame Receive Interface, VC 2
      vc2FrameRxValid   : out sl;                               -- PGP frame data is valid
      vc2RemAlmostFull  : out sl;                               -- Remote buffer almost full
      vc2RemOverflow    : out sl;                               -- Remote buffer overflow

      -- Frame Receive Interface, VC 3
      vc3FrameRxValid   : out sl;                               -- PGP frame data is valid
      vc3RemAlmostFull  : out sl;                               -- Remote buffer almost full
      vc3RemOverflow    : out sl;                               -- Remote buffer overflow

      -- Receive CRC Interface
      crcRxIn           : out slv(RX_LANE_CNT_G*16-1 downto 0); -- Receive data for CRC
      crcRxInit         : out sl;                               -- Receive CRC value init
      crcRxValid        : out sl;                               -- Receive data for CRC is valid
      crcRxOut          : in  slv(31 downto 0)                  -- Receive calculated CRC value
   );

end Pgp2bRxCell;


-- Define architecture
architecture Pgp2bRxCell of Pgp2bRxCell is

   -- Local Signals
   signal dly0SOC           : sl;
   signal dly0SOF           : sl;
   signal dly0EOC           : sl;
   signal dly0EOF           : sl;
   signal dly0EOFE          : sl;
   signal dly0Data          : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal dly1SOC           : sl;
   signal dly1SOF           : sl;
   signal dly1EOC           : sl;
   signal dly1EOF           : sl;
   signal dly1EOFE          : sl;
   signal dly1Data          : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal dly2SOC           : sl;
   signal dly2SOF           : sl;
   signal dly2EOC           : sl;
   signal dly2EOF           : sl;
   signal dly2EOFE          : sl;
   signal dly2Data          : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal dly3SOC           : sl;
   signal dly3SOF           : sl;
   signal dly3EOC           : sl;
   signal dly3EOF           : sl;
   signal dly3EOFE          : sl;
   signal dly3Data          : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal dly4SOC           : sl;
   signal dly4SOF           : sl;
   signal dly4EOC           : sl;
   signal dly4EOF           : sl;
   signal dly4EOFE          : sl;
   signal dly4Data          : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal dly5SOC           : sl;
   signal dly5SOF           : sl;
   signal dly5EOC           : sl;
   signal dly5EOF           : sl;
   signal dly5EOFE          : sl;
   signal dly5Data          : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal dly6SOC           : sl;
   signal dly6SOF           : sl;
   signal dly6EOC           : sl;
   signal dly6EOF           : sl;
   signal dly6EOFE          : sl;
   signal dly6Data          : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal dly7SOC           : sl;
   signal dly7SOF           : sl;
   signal dly7EOC           : sl;
   signal dly7EOF           : sl;
   signal dly7EOFE          : sl;
   signal dly7Data          : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal intCrcRxValid     : sl;
   signal crcNotZero        : sl;
   signal linkDownCnt       : slv(4 downto 0);
   signal compSOC           : sl;
   signal compData          : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal detSOC            : sl;
   signal detSOF            : sl;
   signal outData           : slv(RX_LANE_CNT_G*16-1 downto 0);
   signal detEOC            : sl;
   signal detEOF            : sl;
   signal detEOFE           : sl;
   signal inCellEn          : sl;
   signal nxtCellEn         : sl;
   signal inCellSerErr      : sl;
   signal inCellSOF         : sl;
   signal inCellEOC         : sl;
   signal inCellEOF         : sl;
   signal inCellEOFE        : sl;
   signal inCellCnt         : slv(PAYLOAD_CNT_TOP_G downto 0);
   signal vcInFrame         : slv(3 downto 0);
   signal currVc            : slv(1 downto 0);
   signal serErr            : sl;
   signal vc0Serial         : slv(5 downto 0);
   signal vc0Valid          : sl;
   signal vc1Serial         : slv(5 downto 0);
   signal vc1Valid          : sl;
   signal vc2Serial         : slv(5 downto 0);
   signal vc2Valid          : sl;
   signal vc3Serial         : slv(5 downto 0);
   signal vc3Valid          : sl;
   signal abortVc           : slv(1 downto 0);
   signal abortEn           : sl;
   signal intCellError      : sl;
   signal dlyCellError      : sl;

begin

   -- Delay stages to line up data with CRC calculation
   process ( pgpRxClk ) begin
      if rising_edge(pgpRxClk) then
         if pgpRxClkRst = '1' then
            dly0SOC       <= '0'           after TPD_G;
            dly0SOF       <= '0'           after TPD_G;
            dly0EOC       <= '0'           after TPD_G;
            dly0EOF       <= '0'           after TPD_G;
            dly0EOFE      <= '0'           after TPD_G;
            dly0Data      <= (others=>'0') after TPD_G;
            dly1SOC       <= '0'           after TPD_G;
            dly1SOF       <= '0'           after TPD_G;
            dly1EOC       <= '0'           after TPD_G;
            dly1EOF       <= '0'           after TPD_G;
            dly1EOFE      <= '0'           after TPD_G;
            dly1Data      <= (others=>'0') after TPD_G;
            dly2SOC       <= '0'           after TPD_G;
            dly2SOF       <= '0'           after TPD_G;
            dly2EOC       <= '0'           after TPD_G;
            dly2EOF       <= '0'           after TPD_G;
            dly2EOFE      <= '0'           after TPD_G;
            dly2Data      <= (others=>'0') after TPD_G;
            dly3SOC       <= '0'           after TPD_G;
            dly3SOF       <= '0'           after TPD_G;
            dly3EOC       <= '0'           after TPD_G;
            dly3EOF       <= '0'           after TPD_G;
            dly3EOFE      <= '0'           after TPD_G;
            dly3Data      <= (others=>'0') after TPD_G;
            dly4SOC       <= '0'           after TPD_G;
            dly4SOF       <= '0'           after TPD_G;
            dly4EOC       <= '0'           after TPD_G;
            dly4EOF       <= '0'           after TPD_G;
            dly4EOFE      <= '0'           after TPD_G;
            dly4Data      <= (others=>'0') after TPD_G;
            dly5SOC       <= '0'           after TPD_G;
            dly5SOF       <= '0'           after TPD_G;
            dly5EOC       <= '0'           after TPD_G;
            dly5EOF       <= '0'           after TPD_G;
            dly5EOFE      <= '0'           after TPD_G;
            dly5Data      <= (others=>'0') after TPD_G;
            dly6SOC       <= '0'           after TPD_G;
            dly6SOF       <= '0'           after TPD_G;
            dly6EOC       <= '0'           after TPD_G;
            dly6EOF       <= '0'           after TPD_G;
            dly6EOFE      <= '0'           after TPD_G;
            dly6Data      <= (others=>'0') after TPD_G;
            dly7SOC       <= '0'           after TPD_G;
            dly7SOF       <= '0'           after TPD_G;
            dly7EOC       <= '0'           after TPD_G;
            dly7EOF       <= '0'           after TPD_G;
            dly7EOFE      <= '0'           after TPD_G;
            dly7Data      <= (others=>'0') after TPD_G;
            intCrcRxValid <= '0'           after TPD_G;
         elsif pgpRxClkEn = '1' then
            -- Shift when not paused
            if cellRxPause = '0' then 

               -- Delay stage 0
               dly0SOC   <= cellRxSOC    after TPD_G;
               dly0SOF   <= cellRxSOF    after TPD_G;
               dly0EOC   <= cellRxEOC    after TPD_G;
               dly0EOF   <= cellRxEOF    after TPD_G;
               dly0EOFE  <= cellRxEOFE   after TPD_G;
               dly0Data  <= cellRxData   after TPD_G;

               -- Delay stage 1
               dly1SOC   <= dly0SOC     after TPD_G;
               dly1SOF   <= dly0SOF     after TPD_G;
               dly1EOC   <= dly0EOC     after TPD_G;
               dly1EOF   <= dly0EOF     after TPD_G;
               dly1EOFE  <= dly0EOFE    after TPD_G;
               dly1Data  <= dly0Data    after TPD_G;
              
               -- Delay stage 2
               dly2SOC   <= dly1SOC     after TPD_G;
               dly2SOF   <= dly1SOF     after TPD_G;
               dly2EOC   <= dly1EOC     after TPD_G;
               dly2EOF   <= dly1EOF     after TPD_G;
               dly2EOFE  <= dly1EOFE    after TPD_G;
               dly2Data  <= dly1Data    after TPD_G;

               -- Delay stage 3
               dly3SOC   <= dly2SOC     after TPD_G;
               dly3SOF   <= dly2SOF     after TPD_G;
               dly3EOC   <= dly2EOC     after TPD_G;
               dly3EOF   <= dly2EOF     after TPD_G;
               dly3EOFE  <= dly2EOFE    after TPD_G;
               dly3Data  <= dly2Data    after TPD_G;

               -- Delay stage 4
               dly4SOC   <= dly3SOC     after TPD_G;
               dly4SOF   <= dly3SOF     after TPD_G;
               dly4EOC   <= dly3EOC     after TPD_G;
               dly4EOF   <= dly3EOF     after TPD_G;
               dly4EOFE  <= dly3EOFE    after TPD_G;
               dly4Data  <= dly3Data    after TPD_G;

               -- Delay stage 5
               dly5SOC   <= dly4SOC     after TPD_G;
               dly5SOF   <= dly4SOF     after TPD_G;
               dly5EOC   <= dly4EOC     after TPD_G;
               dly5EOF   <= dly4EOF     after TPD_G;
               dly5EOFE  <= dly4EOFE    after TPD_G;
               dly5Data  <= dly4Data    after TPD_G;

               -- Delay stage 6
               dly6SOC   <= dly5SOC     after TPD_G;
               dly6SOF   <= dly5SOF     after TPD_G;
               dly6EOC   <= dly5EOC     after TPD_G;
               dly6EOF   <= dly5EOF     after TPD_G;
               dly6EOFE  <= dly5EOFE    after TPD_G;
               dly6Data  <= dly5Data    after TPD_G;

               -- Delay stage 7
               dly7SOC   <= dly6SOC     after TPD_G;
               dly7SOF   <= dly6SOF     after TPD_G;
               dly7EOC   <= dly6EOC     after TPD_G;
               dly7EOF   <= dly6EOF     after TPD_G;
               dly7EOFE  <= dly6EOFE    after TPD_G;
               dly7Data  <= dly6Data    after TPD_G;

               -- CRC Enable & partial flag
               if cellRxSOC = '1' then
                 intCrcRxValid <= '1' after TPD_G;
               elsif cellRxEOC = '1' then
                 intCrcRxValid <= '0' after TPD_G;
               end if;
            end if;
         end if;
      end if;
   end process;



   -- CRC Data Output, SOC field overwritten with zeros
   GEN_CRC: for i in 0 to (RX_LANE_CNT_G-1) generate
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
   detEOC   <= dly3EOC  when RX_LANE_CNT_G = 1 else dly4EOC;
   detEOF   <= dly3EOF  when RX_LANE_CNT_G = 1 else dly4EOF;
   detEOFE  <= dly3EOFE when RX_LANE_CNT_G = 1 else dly4EOFE;


   -- Detect current VC, check cell serial number
   process ( pgpRxClk ) begin
      if rising_edge(pgpRxClk) then
         if pgpRxClkRst = '1' then
            currVc    <= (others=>'0') after TPD_G;
            serErr    <= '0'           after TPD_G;
            vc0Serial <= (others=>'0') after TPD_G;
            vc0Valid  <= '0'           after TPD_G;
            vc1Serial <= (others=>'0') after TPD_G;
            vc1Valid  <= '0'           after TPD_G;
            vc2Serial <= (others=>'0') after TPD_G;
            vc2Valid  <= '0'           after TPD_G;
            vc3Serial <= (others=>'0') after TPD_G;
            vc3Valid  <= '0'           after TPD_G;
         elsif pgpRxClkEn = '1' then
            -- Link is down, init counts
            if pgpRxLinkReady = '0' then
               currVc    <= (others=>'0') after TPD_G;
               serErr    <= '0'           after TPD_G;
               vc0Serial <= (others=>'0') after TPD_G;
               vc0Valid  <= '0'           after TPD_G;
               vc1Serial <= (others=>'0') after TPD_G;
               vc1Valid  <= '0'           after TPD_G;
               vc2Serial <= (others=>'0') after TPD_G;
               vc2Valid  <= '0'           after TPD_G;
               vc3Serial <= (others=>'0') after TPD_G;
               vc3Valid  <= '0'           after TPD_G;

            -- Pipeline enable
            elsif cellRxPause = '0' then

               -- SOC for compare
               if compSOC = '1' then 

                  -- Register VC value
                  currVc <= compData(15 downto 14) after TPD_G;

                  -- Compare current count, store current count for future increment
                  case compData(15 downto 14) is

                     -- VC 0
                     when "00" => 
                        if compData(13 downto 8) = vc0Serial then 
                           serErr <= '0' after TPD_G; 
                        else 
                           vc0Serial <= compData(13 downto 8) after TPD_G;
                           serErr    <= vc0Valid              after TPD_G;
                        end if;
                        vc0Valid <= '1' after TPD_G;

                     -- VC 1
                     when "01" =>
                        if compData(13 downto 8) = vc1Serial then 
                           serErr <= '0' after TPD_G; 
                        else 
                           vc1Serial <= compData(13 downto 8) after TPD_G;
                           serErr    <= vc1Valid              after TPD_G;
                        end if;
                        vc1Valid <= '1' after TPD_G;

                     -- VC 2
                     when "10" =>
                        if compData(13 downto 8) = vc2Serial then 
                           serErr <= '0' after TPD_G; 
                        else 
                           vc2Serial <= compData(13 downto 8) after TPD_G;
                           serErr    <= vc2Valid              after TPD_G;
                        end if;
                        vc2Valid <= '1' after TPD_G;

                     -- VC 3
                     when others =>
                        if compData(13 downto 8) = vc3Serial then 
                           serErr <= '0' after TPD_G; 
                        else 
                           vc3Serial <= compData(13 downto 8) after TPD_G;
                           serErr    <= vc3Valid              after TPD_G;
                        end if;
                        vc3Valid <= '1' after TPD_G;
                  end case;

               -- SOC for increment
               elsif detSOC = '1' then 
                  case currVc is
                     when "00"   => vc0Serial <= vc0Serial + 1 after TPD_G;
                     when "01"   => vc1Serial <= vc1Serial + 1 after TPD_G;
                     when "10"   => vc2Serial <= vc2Serial + 1 after TPD_G;
                     when others => vc3Serial <= vc3Serial + 1 after TPD_G;
                  end case;
               end if;
            end if;
         end if;
      end if;
   end process;


   -- Receive cell tracking
   process ( pgpRxClk ) begin
      if rising_edge(pgpRxClk) then
         if pgpRxClkRst = '1' then
            crcNotZero        <= '0'           after TPD_G;
            linkDownCnt       <= (others=>'0') after TPD_G;
            inCellEn          <= '0'           after TPD_G;
            inCellSerErr      <= '0'           after TPD_G;
            inCellSOF         <= '0'           after TPD_G;
            inCellEOC         <= '0'           after TPD_G;
            inCellEOF         <= '0'           after TPD_G;
            inCellEOFE        <= '0'           after TPD_G;
            inCellCnt         <= (others=>'0') after TPD_G;
            abortEn           <= '0'           after TPD_G;
            abortVc           <= (others=>'0') after TPD_G;
            intCellError      <= '0'           after TPD_G;
            dlyCellError      <= '0'           after TPD_G;
            pgpRxCellError    <= '0'           after TPD_G;
            vcInFrame         <= (others=>'0') after TPD_G;
         elsif pgpRxClkEn = '1' then
            -- Cell error edge generation
            dlyCellError   <= intCellError after TPD_G;
            pgpRxCellError <= intCellError and not dlyCellError after TPD_G;

            -- CRC Error
            if crcRxOut = 0 then 
               crcNotZero <= '0' after TPD_G;
            else
               crcNotZero <= '1' after TPD_G;
            end if;

            -- Link down counter
            if pgpRxLinkReady = '1' then
               linkDownCnt <= (others=>'0') after TPD_G;
            elsif linkDownCnt(4) = '0' then
               linkDownCnt <= linkDownCnt + 1 after TPD_G;
            end if;

            -- Count size of each cell received
            if cellRxPause = '0' then
               if inCellEn = '1' then
                  inCellCnt <= inCellCnt - 1 after TPD_G;
               else
                  inCellCnt <= (others=>'1') after TPD_G;
               end if;
            end if;

            -- Link is down. Terminate transmission for any active VCs
            if pgpRxLinkReady = '0' then

               -- Enabled every 4 clocks to ensure proper spacing between generated EOFs
               if linkDownCnt(1 downto 0) = "11" then

                  -- VC is active 
                  if vcInFrame(conv_integer(linkDownCnt(3 downto 2))) = '1' then
                     abortEn <= '1' after TPD_G;
                     vcInFrame(conv_integer(linkDownCnt(3 downto 2))) <= '0' after TPD_G;
                  else
                     abortEn <= '0' after TPD_G;
                  end if;
               else
                  abortEn <= '0' after TPD_G;
               end if;

               -- VC for abort
               abortVc <= linkDownCnt(3 downto 2) after TPD_G;

               -- Clear cell control signals
               inCellEn     <= '0' after TPD_G;
               inCellSerErr <= '0' after TPD_G;
               inCellSOF    <= '0' after TPD_G;
               inCellEOC    <= '0' after TPD_G;
               inCellEOF    <= '0' after TPD_G;
               inCellEOFE   <= '0' after TPD_G;
               intCellError <= '0' after TPD_G;

            -- Link is ready
            else 

               -- Clear abort flags
               abortVc <= (others=>'0') after TPD_G;
               abortEn <= '0'           after TPD_G;

               -- Link flush set
               if pgpRxFlush = '1' then
                  vcInFrame <= (others=>'0') after TPD_G;

               -- Pipeline enable
               elsif cellRxPause = '0' then

                  -- SOC Received
                  if detSOC = '1' then

                     -- Do we output data and mark in frame?
                     -- Yes if SOF is set 
                     -- Yes if already in frame
                     if nxtCellEn = '1' then
                        inCellEn                        <= '1' after TPD_G;
                        vcInFrame(conv_integer(currVc)) <= '1' after TPD_G;
                     end if;

                     -- Do we mark output as SOF?
                     -- Yes if SOF is seen and we are not already in frame
                     if detSOF = '1' and vcInFrame(conv_integer(currVc)) = '0' then
                        inCellSOF <= '1' after TPD_G;
                     end if;

                     -- Do we mark serial error flag?
                     -- Yes if SOF is set and we are already in frame
                     -- Yes if serial number error and we are in frame
                     if vcInFrame(conv_integer(currVc)) = '1' and (detSOF = '1' or serErr = '1') then
                        inCellSerErr <= '1' after TPD_G;
                     end if;
                  
                  -- Mark out of cell after EOC 
                  elsif inCellEOC = '1' then
                     inCellEn     <= '0' after TPD_G;
                     inCellSerErr <= '0' after TPD_G;
                     inCellSOF    <= '0' after TPD_G;

                     -- Clear frame state if EOF
                     if inCellEOF = '1' then
                        vcInFrame(conv_integer(currVc)) <= '0' after TPD_G;
                     end if;

                  -- Clear SOF
                  else
                     inCellSOF <= '0' after TPD_G;
                  end if;

                  -- End of cell, check for short cell case
                  if detEOC = '1' and (inCellEn = '1' or nxtCellEn = '1') then
                     inCellEOC    <= '1'                                   after TPD_G;
                     intCellError <= inCellSerErr or crcNotZero            after TPD_G;

                     -- Cell is too short
                     if detEOF = '0' and inCellCnt /= 1 and EN_SHORT_CELLS_G = 0 then
                        inCellEOF    <= '1' after TPD_G;
                        inCellEOFE   <= '1' after TPD_G;
                        intCellError <= '1' after TPD_G;
                     else
                        inCellEOF    <= detEOF  or inCellSerErr or crcNotZero after TPD_G;
                        inCellEOFE   <= detEOFE or inCellSerErr or crcNotZero after TPD_G;
                        intCellError <= inCellSerErr or crcNotZero            after TPD_G;
                     end if;

                  -- Cell might be too long
                  elsif inCellEn = '1' and inCellCnt = 0 and inCellEOC = '0' then
                     inCellEOC    <= '1' after TPD_G;
                     inCellEOF    <= '1' after TPD_G;
                     inCellEOFE   <= '1' after TPD_G;
                     intCellError <= '1' after TPD_G;
                  else
                     inCellEOC    <= '0' after TPD_G;
                     inCellEOF    <= '0' after TPD_G;
                     inCellEOFE   <= '0' after TPD_G;
                     intCellError <= '0' after TPD_G;
                  end if;
               end if;
            end if;
         end if;
      end if;
   end process;


   -- Do we output data and mark in frame?
   -- Yes if SOF is set
   -- Yes if already in frame
   nxtCellEn <= '1' when (detSOF = '1' or vcInFrame(conv_integer(currVc)) = '1') else '0'; 


   -- Data Output
   process ( pgpRxClk ) begin
      if rising_edge(pgpRxClk) then
         if pgpRxClkRst = '1' then
            vcFrameRxData   <= (others=>'0') after TPD_G;
            vcFrameRxSOF    <= '0'           after TPD_G;
            vcFrameRxEOF    <= '0'           after TPD_G;
            vcFrameRxEOFE   <= '0'           after TPD_G;
            vc0FrameRxValid <= '0'           after TPD_G;
            vc1FrameRxValid <= '0'           after TPD_G;
            vc2FrameRxValid <= '0'           after TPD_G;
            vc3FrameRxValid <= '0'           after TPD_G;
         elsif pgpRxClkEn = '1' then
            -- Data abort is enabled
            if abortEn = '1' then
               case abortVc is
                  when "00" =>
                     vc0FrameRxValid <= '1' after TPD_G;
                     vc1FrameRxValid <= '0' after TPD_G;
                     vc2FrameRxValid <= '0' after TPD_G;
                     vc3FrameRxValid <= '0' after TPD_G;
                  when "01" =>
                     vc0FrameRxValid <= '0' after TPD_G;
                     vc1FrameRxValid <= '1' after TPD_G;
                     vc2FrameRxValid <= '0' after TPD_G;
                     vc3FrameRxValid <= '0' after TPD_G;
                  when "10" =>
                     vc0FrameRxValid <= '0' after TPD_G;
                     vc1FrameRxValid <= '0' after TPD_G;
                     vc2FrameRxValid <= '1' after TPD_G;
                     vc3FrameRxValid <= '0' after TPD_G;
                  when others =>
                     vc0FrameRxValid <= '0' after TPD_G;
                     vc1FrameRxValid <= '0' after TPD_G;
                     vc2FrameRxValid <= '0' after TPD_G;
                     vc3FrameRxValid <= '1' after TPD_G;
               end case;

               -- Abort output
               vcFrameRxSOF   <= '0' after TPD_G;
               vcFrameRxEOF   <= '1' after TPD_G;
               vcFrameRxEOFE  <= '1' after TPD_G;

            -- Pipeline is enabled
            elsif cellRxPause = '0' and inCellEn = '1' then
               case currVc is
                  when "00" =>
                     vc0FrameRxValid <= '1' after TPD_G;
                     vc1FrameRxValid <= '0' after TPD_G;
                     vc2FrameRxValid <= '0' after TPD_G;
                     vc3FrameRxValid <= '0' after TPD_G;
                  when "01" =>
                     vc0FrameRxValid <= '0' after TPD_G;
                     vc1FrameRxValid <= '1' after TPD_G;
                     vc2FrameRxValid <= '0' after TPD_G;
                     vc3FrameRxValid <= '0' after TPD_G;
                  when "10" =>
                     vc0FrameRxValid <= '0' after TPD_G;
                     vc1FrameRxValid <= '0' after TPD_G;
                     vc2FrameRxValid <= '1' after TPD_G;
                     vc3FrameRxValid <= '0' after TPD_G;
                  when others =>
                     vc0FrameRxValid <= '0' after TPD_G;
                     vc1FrameRxValid <= '0' after TPD_G;
                     vc2FrameRxValid <= '0' after TPD_G;
                     vc3FrameRxValid <= '1' after TPD_G;
               end case;

               -- Data output
               vcFrameRxData  <= outData    after TPD_G;
               vcFrameRxSOF   <= inCellSOF  after TPD_G;
               vcFrameRxEOF   <= inCellEOF  after TPD_G;
               vcFrameRxEOFE  <= inCellEOFE after TPD_G;

            -- Paused or no data
            else 
               vc0FrameRxValid <= '0' after TPD_G;
               vc1FrameRxValid <= '0' after TPD_G;
               vc2FrameRxValid <= '0' after TPD_G;
               vc3FrameRxValid <= '0' after TPD_G;
            end if;
         end if;
      end if;
   end process;


   -- Update buffer status on successfull cell reception
   process ( pgpRxClk ) begin
      if rising_edge(pgpRxClk) then
         if pgpRxClkRst = '1' then
            vc0RemAlmostFull <= '1' after TPD_G;
            vc0RemOverflow   <= '0' after TPD_G;
            vc1RemAlmostFull <= '1' after TPD_G;
            vc1RemOverflow   <= '0' after TPD_G;
            vc2RemAlmostFull <= '1' after TPD_G;
            vc2RemOverflow   <= '0' after TPD_G;
            vc3RemAlmostFull <= '1' after TPD_G;
            vc3RemOverflow   <= '0' after TPD_G;
         elsif pgpRxClkEn = '1' then
            -- Link is not ready, force buffer states to bad
            if pgpRxLinkReady = '0' then
               vc0RemAlmostFull <= '1' after TPD_G;
               vc0RemOverflow   <= '0' after TPD_G;
               vc1RemAlmostFull <= '1' after TPD_G;
               vc1RemOverflow   <= '0' after TPD_G;
               vc2RemAlmostFull <= '1' after TPD_G;
               vc2RemOverflow   <= '0' after TPD_G;
               vc3RemAlmostFull <= '1' after TPD_G;
               vc3RemOverflow   <= '0' after TPD_G;

            -- Update buffer status 
            elsif cellRxEOC = '1' then
               vc0RemAlmostFull <= cellRxData(8)  after TPD_G;
               vc0RemOverflow   <= cellRxData(12) after TPD_G;
               vc1RemAlmostFull <= cellRxData(9)  after TPD_G;
               vc1RemOverflow   <= cellRxData(13) after TPD_G;
               vc2RemAlmostFull <= cellRxData(10) after TPD_G;
               vc2RemOverflow   <= cellRxData(14) after TPD_G;
               vc3RemAlmostFull <= cellRxData(11) after TPD_G;
               vc3RemOverflow   <= cellRxData(15) after TPD_G;
            end if;
         end if;
      end if;
   end process;

end Pgp2bRxCell;

