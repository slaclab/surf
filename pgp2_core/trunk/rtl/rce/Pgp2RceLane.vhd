-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, RCE Lane
-- Project       : Reconfigurable Cluster Element
-------------------------------------------------------------------------------
-- File          : Pgp2RceLane.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 01/14/2010
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file for RCE lane interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 01/14/2010: created.
-------------------------------------------------------------------------------
LIBRARY ieee;
use work.all;
use work.Pgp2MgtPackage.all;
--use work.Pgp2TbPackage.all; -- For Simulation
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2RceLane is
   generic (
      MgtMode   : string  := "A";
      RefClkSel : string  := "REFCLK1"
   ); port ( 

      -- Clock and reset     
      pgpClk            : in  std_logic;
      pgpReset          : in  std_logic;

      -- PGP Status
      pllTxRst          : in  std_logic;
      pllRxRst          : in  std_logic;
      pllRxReady        : out std_logic;
      pllTxReady        : out std_logic;
      pgpLocLinkReady   : out std_logic;
      pgpRemLinkReady   : out std_logic;
      pgpLocData        : in  std_logic_vector(7 downto 0);
      pgpRemData        : out std_logic_vector(7 downto 0);

      -- PGP Counters
      cntReset          : in  std_logic;
      pgpCntCellError   : out std_logic_vector(3 downto 0);
      pgpCntLinkDown    : out std_logic_vector(3 downto 0);
      pgpCntLinkError   : out std_logic_vector(3 downto 0);
      pgpRxFifoErr      : out std_logic;
      pgpRxCnt          : out std_logic_vector(3 downto 0);

      -- Lane Number for header
      laneNumber        : in  std_logic_vector(1 downto 0);

      -- VC Receive Signals
      vcFrameRxSOF      : out std_logic;
      vcFrameRxEOF      : out std_logic;
      vcFrameRxEOFE     : out std_logic;
      vcFrameRxData     : out std_logic_vector(63 downto 0);
      vcFrameRxReq      : out std_logic;
      vcFrameRxValid    : out std_logic;
      vcFrameRxReady    : in  std_logic;
      vcFrameRxWidth    : out std_logic_vector(1  downto 0);

      -- VC Transmit Signals
      vcFrameTxVc       : in  std_logic_vector(1 downto 0);
      vcFrameTxValid    : in  std_logic;
      vcFrameTxReady    : out std_logic;
      vcFrameTxSOF      : in  std_logic;
      vcFrameTxEOF      : in  std_logic;
      vcFrameTxEOFE     : in  std_logic;
      vcFrameTxData     : in  std_logic_vector(15 downto 0);

      -- Remote flow control
      vcRemBuffAFull    : out std_logic_vector(3 downto 0);
      vcRemBuffFull     : out std_logic_vector(3 downto 0);

      -- MGT Signals
      mgtLoopback       : in  std_logic;
      mgtRefClk1        : in  std_logic;
      mgtRefClk2        : in  std_logic;
      mgtRxN            : in  std_logic;
      mgtRxP            : in  std_logic;
      mgtTxN            : out std_logic;
      mgtTxP            : out std_logic;
      mgtCombusIn       : in  std_logic_vector(15 downto 0);
      mgtCombusOut      : out std_logic_vector(15 downto 0);

      dclk              : in  std_logic;                     -- MGT Dynamic reconfig port
      den               : in  std_logic;
      dwen              : in  std_logic;
      daddr             : in  std_logic_vector( 7 downto 0);
      ddin              : in  std_logic_vector(15 downto 0);
      drdy              : out std_logic;
      ddout             : out std_logic_vector(15 downto 0);

      -- Debug
      debug             : out std_logic_vector(63 downto 0)

   );
end Pgp2RceLane;


-- Define architecture
architecture Pgp2RceLane of Pgp2RceLane is

   -- Receive FIFO
   component pgp2_v4_fifo_69x512
      port (
         clk:        IN  std_logic;
         rst:        IN  std_logic;
         din:        IN  std_logic_VECTOR(68 downto 0);
         wr_en:      IN  std_logic;
         rd_en:      IN  std_logic;
         dout:       OUT std_logic_VECTOR(68 downto 0);
         full:       OUT std_logic;
         empty:      OUT std_logic;
         data_count: OUT std_logic_VECTOR(8 downto 0)
      );
   end component;

   -- Local Signals
   signal pgpRxCellError  : std_logic;
   signal pgpRxLinkDown   : std_logic;
   signal pgpRxLinkError  : std_logic;
   signal currVc          : std_logic_vector(1 downto 0);
   signal intCntCellError : std_logic_vector(3 downto 0);
   signal intCntLinkDown  : std_logic_vector(3 downto 0);
   signal intCntLinkError : std_logic_vector(3 downto 0);
   signal intCntRx        : std_logic_vector(3 downto 0);
   signal vcLocBuffAFull  : std_logic;
   signal vcLocBuffFull   : std_logic;
   signal intFrameTxValid : std_logic_vector(3 downto 0);
   signal intFrameTxReady : std_logic_vector(3 downto 0);
   signal intLocLinkReady : std_logic;
   signal intFrameRxSOF   : std_logic;
   signal intFrameRxEOF   : std_logic;
   signal intFrameRxEOFE  : std_logic;
   signal intFrameRxData  : std_logic_vector(15 downto 0);
   signal intFrameRxValid : std_logic_vector(3  downto 0);
   signal fifoWrData      : std_logic_vector(68 downto 0);
   signal fifoWrEn        : std_logic;
   signal fifoRdEn        : std_logic;
   signal fifoRdEnDly     : std_logic;
   signal fifoRdData      : std_logic_vector(68 downto 0);
   signal fifoFull        : std_logic;
   signal fifoRst         : std_logic;
   signal fifoEmpty       : std_logic;
   signal fifoCount       : std_logic_vector(8  downto 0);
   signal fifoWrCnt       : std_logic_vector(1  downto 0);
   signal fifoEofCnt      : std_logic_vector(8  downto 0);
   signal fifoEofRd       : std_logic;
   signal fifoEofWr       : std_logic;
   signal intValid        : std_logic;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Output counters
   pgpCntCellError <= intCntCellError;
   pgpCntLinkDown  <= intCntLinkDown;
   pgpCntLinkError <= intCntLinkError;
   pgpRxCnt        <= intCntRx;

   -- Link status
   pgpLocLinkReady <= intLocLinkReady;

   -- Decode VC valid
   intFrameTxValid(0) <= vcFrameTxValid when vcFrameTxVc = 0 else '0';
   intFrameTxValid(1) <= vcFrameTxValid when vcFrameTxVc = 1 else '0';
   intFrameTxValid(2) <= vcFrameTxValid when vcFrameTxVc = 2 else '0';
   intFrameTxValid(3) <= vcFrameTxValid when vcFrameTxVc = 3 else '0';

   -- MUX VC ready
   vcFrameTxReady <= intFrameTxReady(0) when vcFrameTxVc = 0 else
                     intFrameTxReady(1) when vcFrameTxVc = 1 else
                     intFrameTxReady(2) when vcFrameTxVc = 2 else
                     intFrameTxReady(3) when vcFrameTxVc = 3 else '0';

   -- Encode VC
   currVc <= "00" when intFrameRxValid(0) = '1' else
             "01" when intFrameRxValid(1) = '1' else
             "10" when intFrameRxValid(2) = '1' else
             "11";

   -- Error Counters
   process ( pgpClk, pgpReset ) begin
      if pgpReset = '1' then
         intCntCellError <= (others=>'0') after tpd;
         intCntLinkDown  <= (others=>'0') after tpd;
         intCntLinkError <= (others=>'0') after tpd;
         intCntRx        <= (others=>'0') after tpd;
      elsif rising_edge(pgpClk) then

         -- Cell error counter
         if cntReset = '1' then
            intCntCellError <= (others=>'0') after tpd;
         elsif pgpRxCellError = '1' and intCntCellError /= x"F" then
            intCntCellError <= intCntCellError + 1 after tpd;
         end if;

         -- Link error counter
         if cntReset = '1' then
            intCntLinkError <= (others=>'0') after tpd;
         elsif pgpRxLinkError = '1' and intCntLinkError /= x"F" then
            intCntLinkError <= intCntLinkError + 1 after tpd;
         end if;

         -- Link down counter
         if cntReset = '1' then
            intCntLinkDown <= (others=>'0') after tpd;
         elsif pgpRxLinkDown = '1' and intCntLinkDown /= x"F" then
            intCntLinkDown <= intCntLinkDown + 1 after tpd;
         end if;

         -- Rx Counter
         if cntReset = '1' then
            intCntRx <= (others=>'0') after tpd;
         elsif intFrameRxValid /= 0 and intFrameRxEOF = '1' then
            intCntRx <= intCntRx + 1 after tpd;
         end if;

      end if;
   end process;


   -- Receive Buffer Writes
   process ( pgpClk, pgpReset ) begin
      if pgpReset = '1' then
         fifoWrData     <= (others=>'0') after tpd;
         fifoWrEn       <= '0'           after tpd;
         fifoWrCnt      <= "00"          after tpd;
         vcLocBuffAFull <= '0'           after tpd;
         vcLocBuffFull  <= '0'           after tpd;
         pgpRxFifoErr   <= '0'           after tpd;
      elsif rising_edge(pgpClk) then

         -- Almost full 1/4
         vcLocBuffAFull <= fifoFull or fifoCount(8) or fifoCount(7) after tpd;

         -- Full 1/2
         vcLocBuffFull  <= fifoFull or fifoCount(8) after tpd;

         -- Track write errors
         if fifoWrEn = '1' and fifoFull = '1' then
            pgpRxFifoErr  <= '1' after tpd;
         elsif cntReset = '1' then
            pgpRxFifoErr  <= '0' after tpd;
         end if;

         -- Link is down
         if intLocLinkReady = '0' then
            fifoWrEn  <= '0'  after tpd;
            fifoWrCnt <= "00" after tpd;

         -- FIFO is valid
         elsif intFrameRxValid /= 0 then
            fifoWrData(68 downto 67) <= fifoWrCnt      after tpd;
            fifoWrData(66)           <= intFrameRxEOFE after tpd;
            fifoWrData(65)           <= intFrameRxEOF  after tpd;

            -- Save SOF
            if fifoWrCnt = 0 then
               fifoWrData(64) <= intFrameRxSOF after tpd;
            end if;
                  
            -- Which word are we on
            if ( fifoWrCnt = "00" ) then 
               fifoWrData(15 downto  8) <= intFrameRxData(15 downto 8) after tpd; 
               fifoWrData(5  downto  2) <= intFrameRxData(5  downto 2) after tpd; 
               if intFrameRxSOF = '1' then
                  fifoWrData(7 downto 6) <= laneNumber after tpd; -- Overwrite Lane number in header
                  fifoWrData(1 downto 0) <= currVc     after tpd; -- Overwrite VC number in header
               else
                  fifoWrData(7 downto 6) <= intFrameRxData(7 downto 6) after tpd;
                  fifoWrData(1 downto 0) <= intFrameRxData(1 downto 0) after tpd; 
               end if;
            end if;
            if ( fifoWrCnt = "01" ) then fifoWrData(31 downto 16) <= intFrameRxData after tpd; end if;
            if ( fifoWrCnt = "10" ) then fifoWrData(47 downto 32) <= intFrameRxData after tpd; end if;
            if ( fifoWrCnt = "11" ) then fifoWrData(63 downto 48) <= intFrameRxData after tpd; end if;
                  
            -- Reset on EOF
            if intFrameRxEOF = '1' then
               fifoWrCnt <= "00" after tpd;
            else
               fifoWrCnt <= fifoWrCnt + 1 after tpd;
            end if;

            -- Write on EOF or count of 3
            if intFrameRxEOF = '1' or fifoWrCnt = "11" then
               fifoWrEn <= '1' after tpd;
            else
               fifoWrEn <= '0' after tpd;
            end if;
         else
            fifoWrEn <= '0' after tpd;
         end if;
      end if;
   end process;

   -- FIFO reset
   fifoRst <= pgpReset or not intLocLinkReady;

   -- Upstream FIFO, 2 block rams
   U_UsFifo: pgp2_v4_fifo_69x512 port map (
      clk        => pgpClk,
      rst        => fifoRst,
      din        => fifoWrData,
      wr_en      => fifoWrEn,
      rd_en      => fifoRdEn,
      dout       => fifoRdData,
      full       => fifoFull,
      empty      => fifoEmpty,
      data_count => fifoCount
   );

   -- EOF read/write detect
   fifoEofWr <= fifoWrEn    and fifoWrData(65);
   fifoEofRd <= fifoRdEnDly and fifoRdData(65);


   -- Read control
   process ( pgpClk, pgpReset ) begin
      if pgpReset = '1' then
         intValid     <= '0'           after tpd;
         fifoRdEnDly  <= '0'           after tpd;
         fifoEofCnt   <= (others=>'0') after tpd;
         vcFrameRxReq <= '0'           after tpd;
      elsif rising_edge(pgpClk) then

         -- Read occured
         fifoRdEnDly <= fifoRdEn after tpd;

         -- Link is down
         if intLocLinkReady = '0' then
            fifoEofCnt   <= (others=>'0') after tpd;
            intValid     <= '0'           after tpd;
            vcFrameRxReq <= '0'           after tpd;
         else

            -- EOF Counter
            if fifoEofWr = '1' and fifoEofRd = '0' then
               fifoEofCnt <= fifoEofCnt + 1 after tpd;
            elsif fifoEofWr = '0' and fifoEofRd = '1' then
               fifoEofCnt <= fifoEofCnt - 1 after tpd;
            end if;

            -- Track Valid
            if fifoRdEn = '1' then
               intValid <= '1' after tpd;
            elsif vcFrameRxReady = '1' then
               intValid <= '0' after tpd;
            end if;

            -- Valid output, EOF is at output or more than 1 EOF in buffer or 127 entries are in buffer
            if vcFrameRxReady = '0' and intValid = '1' and 
               (fifoEofCnt /= 0 or fifoRdData(65) = '1' or fifoCount >= 63) then
               vcFrameRxReq <= '1' after tpd;
            else
               vcFrameRxReq <= '0' after tpd;
            end if;
         end if;
      end if;
   end process;


   -- Control reads
   fifoRdEn <= (not fifoEmpty) and ((not intValid) or vcFrameRxReady);

   -- Outgoing signals
   vcFrameRxEOFE  <= fifoRdData(66);
   vcFrameRxEOF   <= fifoRdData(65);
   vcFrameRxSOF   <= fifoRdData(64);
   vcFrameRxData  <= fifoRdData(63 downto 0);
   vcFrameRxValid <= intValid;
   vcFrameRxWidth <= fifoRdData(68 downto 67);


   -- 16-bit wrapper
   U_Pgp2Mgt16: entity work.Pgp2Mgt16 
      generic map (
         EnShortCells      => 1,
         VcInterleave      => 1,
         MgtMode           => MgtMode,
         RefClkSel         => RefClkSel
      ) port map (
         pgpClk            => pgpClk,
         pgpReset          => pgpReset,
         pgpFlush          => '0',
         pllTxRst          => pllTxRst,         
         pllRxRst          => pllRxRst,         
         pllRxReady        => pllRxReady,       
         pllTxReady        => pllTxReady,       
         pgpRemData        => pgpRemData,
         pgpLocData        => pgpLocData,
         pgpTxOpCodeEn     => '0',
         pgpTxOpCode       => (others=>'0'),
         pgpRxOpCodeEn     => open,
         pgpRxOpCode       => open,
         pgpLocLinkReady   => intLocLinkReady,
         pgpRemLinkReady   => pgpRemLinkReady,
         pgpRxCellError    => pgpRxCellError,
         pgpRxLinkDown     => pgpRxLinkDown,
         pgpRxLinkError    => pgpRxLinkError,
         vc0FrameTxValid   => intFrameTxValid(0),
         vc0FrameTxReady   => intFrameTxReady(0),
         vc0FrameTxSOF     => vcFrameTxSOF,
         vc0FrameTxEOF     => vcFrameTxEOF,
         vc0FrameTxEOFE    => vcFrameTxEOFE,
         vc0FrameTxData    => vcFrameTxData,
         vc0LocBuffAFull   => vcLocBuffAFull,
         vc0LocBuffFull    => vcLocBuffFull,
         vc1FrameTxValid   => intFrameTxValid(1),
         vc1FrameTxReady   => intFrameTxReady(1),
         vc1FrameTxSOF     => vcFrameTxSOF,
         vc1FrameTxEOF     => vcFrameTxEOF,
         vc1FrameTxEOFE    => vcFrameTxEOFE,
         vc1FrameTxData    => vcFrameTxData,
         vc1LocBuffAFull   => vcLocBuffAFull,
         vc1LocBuffFull    => vcLocBuffFull,
         vc2FrameTxValid   => intFrameTxValid(2),
         vc2FrameTxReady   => intFrameTxReady(2),
         vc2FrameTxSOF     => vcFrameTxSOF,
         vc2FrameTxEOF     => vcFrameTxEOF,
         vc2FrameTxEOFE    => vcFrameTxEOFE,
         vc2FrameTxData    => vcFrameTxData,
         vc2LocBuffAFull   => vcLocBuffAFull,
         vc2LocBuffFull    => vcLocBuffFull,
         vc3FrameTxValid   => intFrameTxValid(3),
         vc3FrameTxReady   => intFrameTxReady(3),
         vc3FrameTxSOF     => vcFrameTxSOF,
         vc3FrameTxEOF     => vcFrameTxEOF,
         vc3FrameTxEOFE    => vcFrameTxEOFE,
         vc3FrameTxData    => vcFrameTxData,
         vc3LocBuffAFull   => vcLocBuffAFull,
         vc3LocBuffFull    => vcLocBuffFull,
         vcFrameRxSOF      => intFrameRxSOF,
         vcFrameRxEOF      => intFrameRxEOF,
         vcFrameRxEOFE     => intFrameRxEOFE,
         vcFrameRxData     => intFrameRxData,
         vc0FrameRxValid   => intFrameRxValid(0),
         vc0RemBuffAFull   => vcRemBuffAFull(0),
         vc0RemBuffFull    => vcRemBuffFull(0),
         vc1FrameRxValid   => intFrameRxValid(1),
         vc1RemBuffAFull   => vcRemBuffAFull(1),
         vc1RemBuffFull    => vcRemBuffFull(1),
         vc2FrameRxValid   => intFrameRxValid(2),
         vc2RemBuffAFull   => vcRemBuffAFull(2),
         vc2RemBuffFull    => vcRemBuffFull(2),
         vc3FrameRxValid   => intFrameRxValid(3),
         vc3RemBuffAFull   => vcRemBuffAFull(3),
         vc3RemBuffFull    => vcRemBuffFull(3),
         mgtLoopback       => mgtLoopback,
         mgtRefClk1        => mgtRefClk1,
         mgtRefClk2        => mgtRefClk2,
         mgtRxRecClk       => open,
         mgtRxN            => mgtRxN,
         mgtRxP            => mgtRxP,
         mgtTxN            => mgtTxN,
         mgtTxP            => mgtTxP,
         mgtCombusIn       => mgtCombusIn,
         mgtCombusOut      => mgtCombusOut,
         dclk              => dclk,
         den               => den,
         dwen              => dwen,
         daddr             => daddr,
         ddin              => ddin,
         drdy              => drdy,
         ddout             => ddout,
         debug             => debug
      );

end Pgp2RceLane;

