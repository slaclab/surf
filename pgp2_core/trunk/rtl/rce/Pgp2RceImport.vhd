-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, RCE Import Block
-- Project       : Reconfigurable Cluster Element
-------------------------------------------------------------------------------
-- File          : Pgp2RceImport.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 09/17/2007
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file for the interface between the PIC Import interface and 
-- the PGP RX Interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 01/16/2010: created.
-- 07/06/2010: Added payload count as generic.
-- 08/24/2010: 32-bit endian swap.
-- 01/09/2013: Fixed import last valid byte size error.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
USE work.Pgp2CorePackage.all;

entity Pgp2RceImport is 
   generic (
      FreeListA     : natural := 1;  -- Free List For Lane 0
      FreeListB     : natural := 2;  -- Free List For Lane 1
      FreeListC     : natural := 3;  -- Free List For Lane 2
      FreeListD     : natural := 4;  -- Free List For Lane 3
      PayloadCntTop : integer := 7   -- Top bit for payload counter
   );
   port ( 

      -- System clock & reset
      pgpClk                       : in  std_logic;
      pgpReset                     : in  std_logic;
      
      -- Import Interface
      Import_Clock                 : out std_logic;
      Import_Core_Reset            : in  std_logic;
      Import_Free_List             : out std_logic_vector( 3 downto 0);
      Import_Advance_Data_Pipeline : out std_logic;
      Import_Data_Last_Line        : out std_logic;
      Import_Data_Last_Valid_Byte  : out std_logic_vector( 2 downto 0);
      Import_Data                  : out std_logic_vector(63 downto 0);
      Import_Data_Pipeline_Full    : in  std_logic;
      Import_Pause                 : in  std_logic;

      -- Link states
      pgpLocLinkReady              : in  std_logic_vector(3  downto 0);

      -- Lane Receive Signals
      vcFrameRxSOF                 : in  std_logic_vector(3  downto 0);
      vcFrameRxEOF                 : in  std_logic_vector(3  downto 0);
      vcFrameRxEOFE                : in  std_logic_vector(3  downto 0);
      vcFrameRxDataA               : in  std_logic_vector(63 downto 0);
      vcFrameRxDataB               : in  std_logic_vector(63 downto 0);
      vcFrameRxDataC               : in  std_logic_vector(63 downto 0);
      vcFrameRxDataD               : in  std_logic_vector(63 downto 0);
      vcFrameRxReq                 : in  std_logic_vector(3  downto 0);
      vcFrameRxValid               : in  std_logic_vector(3  downto 0);
      vcFrameRxReady               : out std_logic_vector(3  downto 0);
      vcFrameRxWidthA              : in  std_logic_vector(1  downto 0);
      vcFrameRxWidthB              : in  std_logic_vector(1  downto 0);
      vcFrameRxWidthC              : in  std_logic_vector(1  downto 0);
      vcFrameRxWidthD              : in  std_logic_vector(1  downto 0);

      -- Big endian mode
      bigEndian                    : in  std_logic;

      -- Debug
      debug                        : out std_logic_vector(63 downto 0)
   );
end Pgp2RceImport;


-- Define architecture
architecture Pgp2RceImport of Pgp2RceImport is

   -- Local Signals
   signal intFrameRxSOF   : std_logic;
   signal intFrameRxEOF   : std_logic;
   signal intFrameRxEOFE  : std_logic;
   signal intFrameRxData  : std_logic_vector(63 downto 0);
   signal intFrameRxValid : std_logic;
   signal intFrameRxWidth : std_logic_vector(1  downto 0);
   signal intLocLinkReady : std_logic;
   signal curSource       : std_logic_vector(1  downto 0);
   signal nxtSource       : std_logic_vector(1  downto 0);
   signal arbSource       : std_logic_vector(1  downto 0);
   signal userStatus      : std_logic_vector(15 downto 0);
   signal dataEn          : std_logic;
   signal statusEn        : std_logic;
   signal lastEn          : std_logic;
   signal firstEn         : std_logic;
   signal curWidthErr     : std_logic;
   signal curEofeErr      : std_logic;
   signal curLinkErr      : std_logic;
   signal nxtLinkErr      : std_logic;
   signal cellCount       : std_logic_vector(PayloadCntTop downto 2);
   signal importAdvance   : std_logic;
   signal importLast      : std_logic;
   signal importLastValid : std_logic_vector(2  downto 0);
   signal importFreeList  : std_logic_vector(3  downto 0);
   signal importData      : std_logic_vector(63 downto 0);

   -- Receive states
   signal   curState  : std_logic_vector(1 downto 0);
   signal   nxtState  : std_logic_vector(1 downto 0);
   constant ST_IDLE   : std_logic_vector(1 downto 0) := "00";
   constant ST_SOC    : std_logic_vector(1 downto 0) := "01";
   constant ST_DATA   : std_logic_vector(1 downto 0) := "10";
   constant ST_STATUS : std_logic_vector(1 downto 0) := "11";

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Outgoing clock
   Import_Clock <= pgpClk;

   -- Decode lane selection
   intFrameRxSOF   <= vcFrameRxSOF(conv_integer(curSource));
   intFrameRxEOF   <= vcFrameRxEOF(conv_integer(curSource));
   intFrameRxEOFE  <= vcFrameRxEOFE(conv_integer(curSource));
   intFrameRxValid <= vcFrameRxValid(conv_integer(curSource));

   -- Ready outputs
   vcFrameRxReady(0) <= dataEn when curSource = 0 else '0';
   vcFrameRxReady(1) <= dataEn when curSource = 1 else '0';
   vcFrameRxReady(2) <= dataEn when curSource = 2 else '0';
   vcFrameRxReady(3) <= dataEn when curSource = 3 else '0';

   -- Data input
   intFrameRxData <= vcFrameRxDataA when curSource = 0 else
                     vcFrameRxDataB when curSource = 1 else
                     vcFrameRxDataC when curSource = 2 else
                     vcFrameRxDataD;

   -- Width input
   intFrameRxWidth <= vcFrameRxWidthA when curSource = 0 else
                      vcFrameRxWidthB when curSource = 1 else
                      vcFrameRxWidthC when curSource = 2 else
                      vcFrameRxWidthD;

   -- PIC Signals
   Import_Advance_Data_Pipeline <= importAdvance;
   Import_Data_Last_Line        <= importLast;
   Import_Data_Last_Valid_Byte  <= importLastValid;
   Import_Free_List             <= importFreeList;
   Import_Data                  <= importData;

   -- Sync state
   process ( pgpClk, pgpReset ) begin
      if pgpReset = '1' then
         curState        <= ST_IDLE       after tpd;
         curSource       <= "00"          after tpd;
         importAdvance   <= '0'           after tpd;
         importLast      <= '0'           after tpd;
         importLastValid <= "000"         after tpd;
         importFreeList  <= (others=>'0') after tpd;
         importData      <= (others=>'0') after tpd;
         userStatus      <= (others=>'0') after tpd;
         curWidthErr     <= '0'           after tpd;
         curEofeErr      <= '0'           after tpd;
         curLinkErr      <= '0'           after tpd;
         cellCount       <= (others=>'0') after tpd;
         intLocLinkReady <= '0'           after tpd;
      elsif rising_edge(pgpClk) then

         -- Link ready of current source
         intLocLinkReady <= pgpLocLinkReady(conv_integer(curSource)) after tpd;

         -- Arbiter reset
         if Import_Core_Reset = '1' then
            curState  <= ST_IDLE after tpd;
            curSource <= "00"    after tpd;
         else
            curState  <= nxtState  after tpd;
            curSource <= nxtSource after tpd;
         end if;

         -- Output signals
         importAdvance   <= dataEn or statusEn or firstEn after tpd;
         importLast      <= lastEn                        after tpd;
         importLastValid <= intFrameRxWidth & "1"         after tpd;

         -- Free list selection
         if firstEn = '1' then
            importFreeList(3 downto 2) <= (others=>'0') after tpd;
            importFreeList(1 downto 0) <= curSource     after tpd;
         else 
            case (curSource) is 
               when "00" => importFreeList <= conv_std_logic_vector(FreeListA,4) after tpd;
               when "01" => importFreeList <= conv_std_logic_vector(FreeListB,4) after tpd;
               when "10" => importFreeList <= conv_std_logic_vector(FreeListC,4) after tpd;
               when "11" => importFreeList <= conv_std_logic_vector(FreeListD,4) after tpd;
               when others => importFreeList <= (others=>'0') after tpd;
            end case;
         end if;

         -- Select Data
         if firstEn = '1' then
            importData <= (others=>'0') after tpd;

         -- Data
         elsif dataEn = '1' then

            -- Little endian
            if bigEndian = '0' then
               importData(63 downto 56) <= intFrameRxData(39 downto 32) after tpd;
               importData(55 downto 48) <= intFrameRxData(47 downto 40) after tpd;
               importData(47 downto 40) <= intFrameRxData(55 downto 48) after tpd;
               importData(39 downto 32) <= intFrameRxData(63 downto 56) after tpd;
               importData(31 downto 24) <= intFrameRxData(7  downto  0) after tpd;
               importData(23 downto 16) <= intFrameRxData(15 downto  8) after tpd;
               importData(15 downto  8) <= intFrameRxData(23 downto 16) after tpd;
               importData(7  downto  0) <= intFrameRxData(31 downto 24) after tpd;

            -- Big endian
            else
               importData <= intFrameRxData after tpd;
            end if;

         -- Status
         elsif statusEn = '1' then
            importData(63 downto 32) <= (others=>'0') after tpd;
            importData(31 downto 16) <= userStatus    after tpd;
            importData(15 downto  4) <= (others=>'0') after tpd;
            importData(3)            <= curLinkErr    after tpd;
            importData(2)            <= curWidthErr   after tpd;
            importData(1)            <= curEofeErr    after tpd;

            -- User status
            if userStatus /= 0 then
               importData(5) <= '1' after tpd;
            else
               importData(5) <= '0' after tpd;
            end if;

            -- Error bit
            if userStatus /= 0 or curLinkErr = '1' or 
               curWidthErr = '1' or curEofeErr = '1' then
               importData(0) <= '1' after tpd;
            else
               importData(0) <= '0' after tpd;
            end if;
         end if;

         -- CELL Counter
         if firstEn = '1' then
            cellCount <= (others=>'1') after tpd;
         elsif dataEn = '1' then
            cellCount <= cellCount - 1 after tpd;
         end if;

         -- Last line, store status
         if lastEn = '1' then
            if intFrameRxWidth(1) = '0' then
               userStatus <= intFrameRxData(31 downto 16) after tpd;
            else
               userStatus <= intFrameRxData(63 downto 48) after tpd;
            end if;
            curWidthErr <= not intFrameRxWidth(0) after tpd;
            curEOFEErr  <= intFrameRxEOFE         after tpd;
         end if;

         -- SOF error
         curLinkErr <= nxtLinkErr  after tpd;
      end if;
   end process;


   -- State transition
   process ( curState, curSource, arbSource, vcFrameRxReq, Import_Pause, 
             Import_Data_Pipeline_Full, intLocLinkReady, cellCount, Import_Core_Reset,
             intFrameRxEOF, intFrameRxValid, curLinkErr ) begin

      case curState is 

         -- Idle, New Request
         when ST_IDLE =>
            dataEn       <= '0';
            statusEn     <= '0';
            lastEn       <= '0';
            firstEn      <= '0';
            nxtLinkErr   <= '0';

            -- New requester
            if Import_Core_Reset = '0' and vcFrameRxReq /= 0 then
               nxtSource <= arbSource;
               nxtState  <= ST_SOC;
            else
               nxtSource <= curSource;
               nxtState  <= curState;
            end if;

         -- Start of cell, write blank data and VC value
         when ST_SOC =>
            dataEn       <= '0';
            lastEn       <= '0';
            nxtLinkErr   <= '0';
            statusEn     <= '0';
            nxtSource    <= curSource;

            -- Link is lost on selected channel
            if intLocLinkReady = '0' then
               firstEn   <= '0';
               nxtState  <= ST_IDLE;

            -- Data is ready and pipeline is ready
            elsif Import_Pause = '0' and Import_Data_Pipeline_Full = '0' then
               firstEn  <= '1';
               nxtState <= ST_DATA;
            else
               firstEn  <= '0';
               nxtState <= curState;
            end if;

         -- Read Data
         when ST_DATA =>
            firstEn      <= '0';
            statusEn     <= '0';
            nxtSource    <= curSource;

            -- Link is lost on selected channel
            if intLocLinkReady = '0' then
               nxtLinkErr <= '1';
               dataEn     <= '1';
               lastEn     <= '1';
               nxtState   <= ST_STATUS;

            -- Data is ready and pipeline is ready
            elsif Import_Pause = '0' and Import_Data_Pipeline_Full = '0' and intFrameRxValid = '1' then
               nxtLinkErr <= '0';
               dataEn     <= '1';

               -- Last line is set
               if intFrameRxEOF = '1' then
                  lastEn   <= '1';
                  nxtState <= ST_STATUS;

               -- Last word of cell
               elsif cellCount = 0 then
                  lastEn   <= '0';
                  nxtState <= ST_IDLE;
               else
                  lastEn   <= '0';
                  nxtState <= curState;
               end if;
            else
               nxtLinkErr <= '0';
               dataEn     <= '0';
               lastEn     <= '0';
               nxtState   <= curState;
            end if;

         -- Status Write
         when ST_STATUS =>
            nxtLinkErr   <= curLinkErr;
            nxtSource    <= curSource;
            dataEn       <= '0';
            lastEn       <= '0';
            firstEn      <= '0';

            -- Data is ready and pipeline is ready
            if Import_Data_Pipeline_Full = '0' then
               statusEn <= '1';
               nxtState <= ST_IDLE;
            else
               statusEn <= '0';
               nxtState <= curState;
            end if;

         -- Default
         when others =>
            nxtLinkErr   <= '0';
            nxtSource    <= "00";
            dataEn       <= '0';
            lastEn       <= '0';
            firstEn      <= '0';
            statusEn     <= '0';
            nxtState     <= ST_IDLE;
      end case;
   end process;


   -- Block to determine next data source
   process ( curSource, vcFrameRxReq ) begin
      case curSource is 
         when "00" => 
            if    vcFrameRxReq(1) = '1' then arbSource <= "01";
            elsif vcFrameRxReq(2) = '1' then arbSource <= "10";
            elsif vcFrameRxReq(3) = '1' then arbSource <= "11";
            elsif vcFrameRxReq(0) = '1' then arbSource <= "00";
            else arbSource <= "00"; end if;
         when "01" => 
            if    vcFrameRxReq(2) = '1' then arbSource <= "10";
            elsif vcFrameRxReq(3) = '1' then arbSource <= "11";
            elsif vcFrameRxReq(0) = '1' then arbSource <= "00";
            elsif vcFrameRxReq(1) = '1' then arbSource <= "01";
            else arbSource <= "00"; end if;
         when "10" => 
            if    vcFrameRxReq(3) = '1' then arbSource <= "11";
            elsif vcFrameRxReq(0) = '1' then arbSource <= "00";
            elsif vcFrameRxReq(1) = '1' then arbSource <= "01";
            elsif vcFrameRxReq(2) = '1' then arbSource <= "10";
            else arbSource <= "00"; end if;
         when "11" => 
            if    vcFrameRxReq(0) = '1' then arbSource <= "00";
            elsif vcFrameRxReq(1) = '1' then arbSource <= "01";
            elsif vcFrameRxReq(2) = '1' then arbSource <= "10";
            elsif vcFrameRxReq(3) = '1' then arbSource <= "11";
            else arbSource <= "00"; end if;
         when others => arbSource <= "00";
      end case;
   end process;

   -- Debug
   debug(63 downto 56) <= importData(7 downto 0);
   debug(55 downto 52) <= vcFrameRxReq;
   debug(51 downto 48) <= vcFrameRxEOFE;
   debug(47 downto 44) <= vcFrameRxEOF;
   debug(43 downto 40) <= vcFrameRxSOF;
   debug(39 downto 36) <= vcFrameRxValid;
   debug(35)           <= intFrameRxEOFE;
   debug(34)           <= Import_Data_Pipeline_Full;
   debug(33)           <= Import_Pause;
   debug(32 downto 29) <= pgpLocLinkReady;
   debug(28 downto 27) <= userStatus(1 downto 0);
   debug(26 downto 23) <= importFreeList;
   debug(22 downto 20) <= importLastValid;
   debug(19 downto 18) <= intFrameRxWidth;
   debug(17)           <= intLocLinkReady;
   debug(16)           <= curLinkErr;
   debug(15)           <= curEofeErr;
   debug(14)           <= curWidthErr;
   debug(13)           <= firstEn;
   debug(12)           <= lastEn;
   debug(11)           <= statusEn;
   debug(10)           <= dataEn;
   debug(9  downto  8) <= curSource;
   debug(7)            <= intFrameRxValid;
   debug(6)            <= Import_Core_Reset;
   debug(5)            <= intFrameRxEOF;
   debug(4)            <= intFrameRxSOF;
   debug(3  downto  2) <= curState;
   debug(1)            <= importLast;
   debug(0)            <= importAdvance;

end Pgp2RceImport;

