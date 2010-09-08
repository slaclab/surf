-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, RCE Export Block
-- Project       : Reconfigurable Cluster Element
-------------------------------------------------------------------------------
-- File          : Pgp2RceExport.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 01/16/2010
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file for the interface between the PIC Export interface and 
-- the PGP TX Interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 01/16/2010: created.
-- 08/24/2010: 32-bit endian swap.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2RceExport is port ( 
     
      -- System clock & reset
      pgpClk                         : in  std_logic;
      pgpReset                       : in  std_logic;

      -- PIC Export Interface
      Export_Clock                   : out std_logic;
      Export_Core_Reset              : in  std_logic;
      Export_Data_Available          : in  std_logic;
      Export_Data_Start              : in  std_logic;
      Export_Advance_Data_Pipeline   : out std_logic;
      Export_Data_Last_Line          : in  std_logic;
      Export_Data_Last_Valid_Byte    : in  std_logic_vector( 2 downto 0);
      Export_Data                    : in  std_logic_vector(63 downto 0);
      Export_Advance_Status_Pipeline : out std_logic;
      Export_Status                  : out std_logic_vector(31 downto 0);
      Export_Status_Full             : in  std_logic;

      -- Remote Link Status
      pgpRemLinkReady                : in  std_logic_vector(3 downto 0);

      -- Common Transmit Signals
      vcFrameTxVc                    : out std_logic_vector(1 downto 0);
      vcFrameTxSOF                   : out std_logic;
      vcFrameTxEOF                   : out std_logic;
      vcFrameTxEOFE                  : out std_logic;
      vcFrameTxData                  : out std_logic_vector(15 downto 0);

      -- Transmit Control Signals, one per lane
      vcFrameTxValid                 : out std_logic_vector(3 downto 0);
      vcFrameTxReady                 : in  std_logic_vector(3 downto 0);

      -- Remote flow control, one per lane/vc
      vcRemBuffAFull                 : in  std_logic_vector(15 downto 0);
      vcRemBuffFull                  : in  std_logic_vector(15 downto 0);

      -- Big endian mode
      bigEndian                      : in  std_logic;

      -- Debug
      debug                          : out std_logic_vector(63 downto 0)
   );
end Pgp2RceExport;


-- Define architecture
architecture Pgp2RceExport of Pgp2RceExport is

   -- Local Signals
   signal pgpReady     : std_logic;
   signal intLinkReady : std_logic;
   signal pgpTxValid0  : std_logic;
   signal pgpTxSOF0    : std_logic;
   signal pgpTxEOF0    : std_logic;
   signal pgpTxEOFE0   : std_logic;
   signal pgpTxData0   : std_logic_vector(15 downto 0);
   signal pgpTxValid1  : std_logic;
   signal pgpTxEOF1    : std_logic;
   signal pgpTxEOFE1   : std_logic;
   signal pgpTxData1   : std_logic_vector(15 downto 0);
   signal pgpTxValid2  : std_logic;
   signal pgpTxEOF2    : std_logic;
   signal pgpTxData2   : std_logic_vector(15 downto 0);
   signal pgpTxValid3  : std_logic;
   signal pgpTxEOF3    : std_logic;
   signal pgpTxData3   : std_logic_vector(15 downto 0);
   signal expVc        : std_logic_vector(1  downto 0);
   signal expLane      : std_logic_vector(1  downto 0);
   signal expCID       : std_logic_vector(23 downto 0);
   signal expSOF       : std_logic;
   signal exportRd     : std_logic;
   signal exportWr     : std_logic;
   signal statusWr     : std_logic;
   signal statusBad    : std_logic;
   signal pgpAFull     : std_logic;
   signal pgpFull      : std_logic;

   -- Transmit states
   signal   curTxState  : std_logic_vector(3 downto 0);
   signal   nxtTxState  : std_logic_vector(3 downto 0);
   constant TX_IDLE     : std_logic_vector(3 downto 0) := "0000";
   constant TX_VC       : std_logic_vector(3 downto 0) := "0001";
   constant TX_SOF      : std_logic_vector(3 downto 0) := "0010";
   constant TX_WAIT     : std_logic_vector(3 downto 0) := "0011";
   constant TX_READ     : std_logic_vector(3 downto 0) := "0100";
   constant TX_DUMP     : std_logic_vector(3 downto 0) := "0101";
   constant TX_SBAD_A   : std_logic_vector(3 downto 0) := "0110";
   constant TX_SBAD_B   : std_logic_vector(3 downto 0) := "0111";
   constant TX_SOK      : std_logic_vector(3 downto 0) := "1000";

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Drive Export Clock and Read
   Export_Clock                 <= pgpClk;
   Export_Advance_Data_Pipeline <= exportRd;

   -- Valid to VCs
   vcFrameTxValid(0) <= pgpTxValid0 when expLane = 0 else '0';
   vcFrameTxValid(1) <= pgpTxValid0 when expLane = 1 else '0';
   vcFrameTxValid(2) <= pgpTxValid0 when expLane = 2 else '0';
   vcFrameTxValid(3) <= pgpTxValid0 when expLane = 3 else '0';
   vcFrameTxVc       <= expVc;

   -- VC Data
   vcFrameTxSOF  <= pgpTxSOF0;
   vcFrameTxEOF  <= pgpTxEOF0;
   vcFrameTxEOFE <= pgpTxEOFE0;
   vcFrameTxData <= pgpTxData0;
   vcFrameTxVc   <= expVc;

   -- VC Ready Signals
   pgpReady <= vcFrameTxReady(conv_integer(expLane));

   -- Link ready signal
   intLinkReady <= pgpRemLinkReady(conv_integer(expLane));

   -- Select Flow Control
   pgpAFull <= vcRemBuffAFull(conv_integer(expLane & expVc));
   pgpFull  <= vcRemBuffFull(conv_integer(expLane & expVc));

   -- Pipeline for data going to PGP
   process ( pgpClk, pgpReset ) begin
      if pgpReset = '1' then
         pgpTxValid0 <= '0'           after tpd;
         pgpTxSOF0   <= '0'           after tpd;
         pgpTxEOF0   <= '0'           after tpd;
         pgpTxEOFE0  <= '0'           after tpd;
         pgpTxData0  <= (others=>'0') after tpd;
         pgpTxValid1 <= '0'           after tpd;
         pgpTxEOF1   <= '0'           after tpd;
         pgpTxEOFE1  <= '0'           after tpd;
         pgpTxData1  <= (others=>'0') after tpd;
         pgpTxValid2 <= '0'           after tpd;
         pgpTxEOF2   <= '0'           after tpd;
         pgpTxData2  <= (others=>'0') after tpd;
         pgpTxValid3 <= '0'           after tpd;
         pgpTxEOF3   <= '0'           after tpd;
         pgpTxData3  <= (others=>'0') after tpd;
      elsif rising_edge(pgpClk) then

         -- Core reset or link down. Clear Valid
         if Export_Core_Reset = '1' and intLinkReady = '0' then
            pgpTxValid0 <= '0' after tpd;
            pgpTxValid1 <= '0' after tpd;
            pgpTxValid2 <= '0' after tpd;
            pgpTxValid3 <= '0' after tpd;

         -- Data shift from Export Control
         elsif exportWr = '1' then

            -- Set SOF0
            pgpTxSOF0 <= expSOF after tpd;

            -- Little endian data
            if bigEndian = '0' then
               pgpTxData0(7  downto  0) <= Export_Data(31 downto 24) after tpd;
               pgpTxData0(15 downto  8) <= Export_Data(23 downto 16) after tpd;
               pgpTxData1(7  downto  0) <= Export_Data(15 downto  8) after tpd;
               pgpTxData1(15 downto  8) <= Export_Data(7  downto  0) after tpd;
               pgpTxData2(7  downto  0) <= Export_Data(63 downto 56) after tpd;
               pgpTxData2(15 downto  8) <= Export_Data(55 downto 48) after tpd;
               pgpTxData3(7  downto  0) <= Export_Data(47 downto 40) after tpd;
               pgpTxData3(15 downto  8) <= Export_Data(39 downto 32) after tpd;

            -- Big endian data
            else
               pgpTxData0 <= Export_Data(15 downto  0) after tpd;
               pgpTxData1 <= Export_Data(31 downto 16) after tpd;
               pgpTxData2 <= Export_Data(47 downto 32) after tpd;
               pgpTxData3 <= Export_Data(63 downto 48) after tpd;
            end if;

            -- Valid, EOF & Width Depend On Last Line/Valid Byte Flags
            if Export_Data_Last_Line = '1' then 

               -- Init VCs and EOF Flags
               pgpTxValid0 <= '1'     after tpd;
               pgpTxEOF0   <= '0'     after tpd;
               pgpTxEOFE0  <= '0'     after tpd;
               pgpTxValid1 <= '1'     after tpd;
               pgpTxEOF2   <= '0'     after tpd;

               -- Determine last transfer size
               case Export_Data_Last_Valid_Byte is
                  when "011"   => -- 32-bits
                     pgpTxEOF1   <= '1'     after tpd;
                     pgpTxEOFE1  <= '0'     after tpd;
                     pgpTxValid2 <= '0'     after tpd;
                     pgpTxValid3 <= '0'     after tpd;
                     pgpTxEOF3   <= '0'     after tpd;
                  when "111"   => -- 64-bits
                     pgpTxEOF1   <= '0'     after tpd;
                     pgpTxEOFE1  <= '0'     after tpd;
                     pgpTxValid2 <= '1'     after tpd;
                     pgpTxValid3 <= '1'     after tpd;
                     pgpTxEOF3   <= '1'     after tpd;
                  when others => -- Invalid Alignment
                     pgpTxEOF1   <= '1'     after tpd;
                     pgpTxEOFE1  <= '1'     after tpd;
                     pgpTxValid2 <= '0'     after tpd;
                     pgpTxValid3 <= '0'     after tpd;
                     pgpTxEOF3   <= '0'     after tpd;
               end case;

            -- Normal data shift
            else
               pgpTxValid0 <= '1'     after tpd;
               pgpTxEOF0   <= '0'     after tpd;
               pgpTxEOFE0  <= '0'     after tpd;
               pgpTxValid1 <= '1'     after tpd;
               pgpTxEOF1   <= '0'     after tpd;
               pgpTxValid2 <= '1'     after tpd;
               pgpTxEOF2   <= '0'     after tpd;
               pgpTxValid3 <= '1'     after tpd;
               pgpTxEOF3   <= '0'     after tpd;
            end if;

         -- Otherwise shift data for each PGP transfer
         elsif pgpTxValid0 = '1' and pgpReady = '1' then

            -- Clear SOF
            pgptxSOF0 <= '0' after tpd;

            -- Shift Data
            pgpTxData0 <= pgpTxData1    after tpd;
            pgpTxData1 <= pgpTxData2    after tpd;
            pgpTxData2 <= pgpTxData3    after tpd;
            pgpTxData3 <= (others=>'0') after tpd;

            -- Shift Valid
            pgpTxValid0 <= pgpTxValid1   after tpd;
            pgpTxValid1 <= pgpTxValid2   after tpd;
            pgpTxValid2 <= pgpTxValid3   after tpd;
            pgpTxValid3 <= '0'           after tpd;

            -- Shift EOF
            pgpTxEOF0 <= pgpTxEOF1 after tpd;
            pgpTxEOF1 <= pgpTxEOF2 after tpd;
            pgpTxEOF2 <= pgpTxEOF3 after tpd;
            pgpTxEOF3 <= '0'       after tpd;

            -- Shift EOFE
            pgpTxEOFE0 <= pgpTxEOFE1 after tpd;
            pgpTxEOFE1 <= '0'        after tpd;
         end if;
      end if;
   end process;


   -- State machine to control read from PIC Interface
   process ( pgpClk, pgpReset ) begin
      if pgpReset = '1' then
         curTxState                     <= TX_IDLE       after tpd;
         expVc                          <= (others=>'0') after tpd;
         expLane                        <= (others=>'0') after tpd;
         expCID                         <= (others=>'0') after tpd;
         Export_Advance_Status_Pipeline <= '0'           after tpd;
         Export_Status                  <= (others=>'0') after tpd;
      elsif rising_edge(pgpClk) then

         -- Reset state on protocol reset or link down
         if Export_Core_Reset = '1' then
            curTxState <= TX_IDLE after tpd;
         else
            curTxState <= nxtTxState after tpd;
         end if;

         -- Store CID, VC, Lane
         if expSOF = '1' then

            -- Little endian
            if bigEndian = '0' then
               expCID(23 downto 16) <= Export_Data(7  downto  0) after tpd;
               expCID(15 downto  8) <= Export_Data(15 downto  8) after tpd;
               expCID(7  downto  0) <= Export_Data(23 downto 16) after tpd;
               expVc                <= Export_Data(25 downto 24) after tpd;
               expLane              <= Export_Data(31 downto 30) after tpd;

            -- Big endian
            else
               expCID  <= Export_Data(31 downto 8) after tpd;
               expVc   <= Export_Data(1  downto 0) after tpd;
               expLane <= Export_Data(7  downto 6) after tpd;
            end if;
         end if;

         -- Status Write
         Export_Advance_Status_Pipeline <= statusWr      after tpd;
         Export_Status(31 downto 8)     <= expCID        after tpd;
         Export_Status(7  downto 2)     <= (others=>'0') after tpd;
         Export_Status(1)               <= statusBad     after tpd;
         Export_Status(0)               <= statusBad     after tpd;
      end if;
   end process;


   -- Combinitorial transmit state logic
   process ( curTxState, Export_Data_Available, Export_Data_Start, pgpReset,
             Export_Data_Last_Line, Export_Core_Reset, pgpTxValid0, pgpTxValid1, 
             pgpReady, pgpAFull, pgpFull, Export_Status_Full, intLinkReady ) begin

      case curTxState is 

         -- Idle, Ready to read first cell from PIC
         when TX_IDLE =>

            -- No Write
            exportWr  <= '0';
            statusWr  <= '0';
            statusBad <= '0';
            expSOF    <= '0';

            -- Wait for start indication from PIC, Wait for PGP shift to be idle.
            if Export_Core_Reset = '0' and pgpReset = '0' and pgpTxValid0 = '0' and
                  Export_Data_Start = '1' and Export_Data_Available = '1' then
               exportRd   <= '1';
               nxtTxState <= TX_VC;
            else
               exportRd   <= '0';
               nxtTxState <= curTxState;
            end if;

         -- Register VC, Lane and CID
         when TX_VC =>

            -- No read or write
            exportRd  <= '0';
            exportWr  <= '0';
            statusWr  <= '0';
            statusBad <= '0';
            expSOF    <= '1';

            -- Go to SOF state
            nxtTxState <= TX_SOF;

         -- Transfer SOF
         when TX_SOF =>

            -- No read
            exportRd  <= '0';
            statusWr  <= '0';
            statusBad <= '0';
            expSOF    <= '1';

            -- Link is down for selected lane
            if intLinkReady = '0' then
               exportWr   <= '0';
               nxtTxState <= TX_DUMP;

            -- PGP Almost Full Flag is asserted, pause
            elsif pgpAFull = '1' then
               exportWr   <= '0';
               nxtTxState <= curTxState;

            -- Output of shift register is empty
            elsif pgpTxValid0 = '0' then
               nxtTxState <= TX_WAIT;
               exportWr   <= '1';

            -- Wait
            else
               nxtTxState <= curTxState;
               exportWr   <= '0';
            end if;

         -- Write just occured to shift register. Wait for next data
         -- to be available on PIC export. Also check for last line.
         when TX_WAIT =>

            -- No Write
            exportWr  <= '0';
            statusWr  <= '0';
            statusBad <= '0';
            expSOF    <= '0';

            -- Link is down for selected lane
            if intLinkReady = '0' then
               exportRd   <= '0';
               nxtTxState <= TX_DUMP;

            -- Last byte was sent
            elsif Export_Data_Last_Line = '1' then
               exportRd   <= '0';
               nxtTxState <= TX_SOK;

            -- Next data is ready
            elsif Export_Data_Available = '1' then
               exportRd   <= '1';
               nxtTxState <= TX_READ;

            -- Wait
            else
               exportRd   <= '0';
               nxtTxState <= curTxState;
            end if;

         -- Data read from PIC Interface
         -- Wait for shift of PGP data before writing to shift register
         when TX_READ =>

            -- No Read
            exportRd  <= '0';
            statusWr  <= '0';
            statusBad <= '0';
            expSOF    <= '0';

            -- Link is down for selected lane
            if intLinkReady = '0' then
               exportWr   <= '0';
               nxtTxState <= TX_DUMP;

            -- Output of shift register is empty
            -- or 2nd stage is empty and shift is about to occur
            elsif pgpTxValid0 = '0' or (pgpTxValid1 = '0' and pgpReady = '1') then

               -- Full flag is asserted, pause
               if pgpFull = '1' then
                  exportWr   <= '0';
                  nxtTxState <= curTxState;
               else
                  exportWr   <= '1';
                  nxtTxState <= TX_WAIT;
               end if;
            else
               exportWr   <= '0';
               nxtTxState <= curTxState;
            end if;

         -- Dump Data
         when TX_DUMP =>

            -- No Write 
            exportWr  <= '0';
            statusWr  <= '0';
            statusBad <= '0';
            expSOF    <= '0';

            -- Last byte was sent
            if Export_Data_Last_Line = '1' then
               exportRd   <= '0';
               nxtTxState <= TX_SBAD_A;

            -- Next data is ready
            elsif Export_Data_Available = '1' then
               exportRd   <= '1';
               nxtTxState <= curTxState;

            -- Wait
            else
               exportRd   <= '0';
               nxtTxState <= curTxState;
            end if;

         -- Write bad status, word 0
         when TX_SBAD_A =>

            -- No Write or Read
            exportWr  <= '0';
            exportRd  <= '0';
            expSOF    <= '0';
            statusBad <= '1';

            -- Wait for status to be ready
            if Export_Status_Full = '0' then
               statusWr   <= '1';
               nxtTxState <= TX_SBAD_B;
            else
               statusWr   <= '0';
               nxtTxState <= curTxState;
            end if;

         -- Write bad status, word 1
         when TX_SBAD_B =>

            -- No Write or Read
            exportWr  <= '0';
            exportRd  <= '0';
            expSOF    <= '0';
            statusBad <= '1';

            -- Wait for status to be ready
            if Export_Status_Full = '0' then
               statusWr   <= '1';
               nxtTxState <= TX_IDLE;
            else
               statusWr   <= '0';
               nxtTxState <= curTxState;
            end if;

         -- Write ok status 
         when TX_SOK =>

            -- No Write or Read
            exportWr  <= '0';
            exportRd  <= '0';
            expSOF    <= '0';
            statusBad <= '0';

            -- Wait for status to be ready
            if Export_Status_Full = '0' then
               statusWr   <= '1';
               nxtTxState <= TX_IDLE;
            else
               statusWr   <= '0';
               nxtTxState <= curTxState;
            end if;

         when others =>
            expSOF     <= '0';
            exportWr   <= '0';
            statusWr   <= '0';
            statusBad  <= '0';
            exportRd   <= '0';
            nxtTxState <= TX_IDLE;
      end case;
   end process;

   -- Debug
   debug(63 downto 56) <= Export_Data(7 downto 0);
   debug(55 downto 48) <= vcRemBuffAFull(7 downto 0);
   debug(47 downto 40) <= vcRemBuffFull(7 downto 0);
   debug(39 downto 36) <= pgpRemLinkReady;
   debug(35 downto 32) <= vcFrameTxReady;
   debug(31)           <= pgpTxValid0;
   debug(30)           <= pgpTxSOF0;
   debug(29)           <= pgpTxEOF0;
   debug(28)           <= pgpTxEOFE0;
   debug(27)           <= pgpTxValid1;
   debug(26)           <= pgpTxEOF1;
   debug(25)           <= pgpTxEOFE1;
   debug(24)           <= pgpTxValid2;
   debug(23)           <= pgpTxEOF2;
   debug(22)           <= pgpTxValid3;
   debug(21)           <= pgpTxEOF3;
   debug(20)           <= expSOF;
   debug(19)           <= pgpAFull;
   debug(18)           <= pgpFull;
   debug(17 downto 16) <= expVc;
   debug(15 downto 14) <= expLane;
   debug(13)           <= Export_Status_Full;
   debug(12)           <= Export_Data_Last_Line;
   debug(11 downto  9) <= Export_Data_Last_Valid_Byte;
   debug(8)            <= pgpReady;
   debug(7)            <= intLinkReady;
   debug(6)            <= statusBad;
   debug(5)            <= statusWr;
   debug(4)            <= exportWr;
   debug(3)            <= exportRd;
   debug(2)            <= Export_Data_Start;
   debug(1)            <= Export_Core_Reset;
   debug(0)            <= Export_Data_Available;

end Pgp2RceExport;

