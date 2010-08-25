-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, RCE Interface
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Rce4x.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 06/06/2007
-------------------------------------------------------------------------------
-- Description:
-- VHDL source for PGP2 interface to RCE. 4-Lane version.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 01/18/2010: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
use work.all;
use work.Pgp2RcePackage.all;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity Pgp2Rce4x is 
   generic (
      FreeListA  : natural := 1;         -- Free List For VC 0
      FreeListB  : natural := 2;         -- Free List For VC 1
      FreeListC  : natural := 3;         -- Free List For VC 2
      FreeListD  : natural := 4;         -- Free List For VC 3
      RefClkSel  : string  := "REFCLK1"  -- Reference Clock To Use "REFCLK1" or "REFCLK2"
   );
   port ( 
      
      -- Import Interface
      Import_Clock                    : out std_logic;
      Import_Core_Reset               : in  std_logic;
      Import_Free_List                : out std_logic_vector( 3 downto 0);
      Import_Advance_Data_Pipeline    : out std_logic;
      Import_Data_Last_Line           : out std_logic;
      Import_Data_Last_Valid_Byte     : out std_logic_vector( 2 downto 0);
      Import_Data                     : out std_logic_vector(63 downto 0);
      Import_Data_Pipeline_Full       : in  std_logic;
      Import_Pause                    : in  std_logic;

      -- Export Interface
      Export_Clock                    : out std_logic;
      Export_Core_Reset               : in  std_logic;
      Export_Data_Available           : in  std_logic;
      Export_Data_Start               : in  std_logic;
      Export_Advance_Data_Pipeline    : out std_logic;
      Export_Data_Last_Line           : in  std_logic;
      Export_Data_Last_Valid_Byte     : in  std_logic_vector( 2 downto 0);
      Export_Data                     : in  std_logic_vector(63 downto 0);
      Export_Advance_Status_Pipeline  : out std_logic;
      Export_Status                   : out std_logic_vector(31 downto 0);
      Export_Status_Full              : in  std_logic;

      -- DCR Bus
      Dcr_Clock                       : in  std_logic;
      Dcr_Write                       : in  std_logic;
      Dcr_Write_Data                  : in  std_logic_vector(31 downto 0);
      Dcr_Read_Address                : in  std_logic_vector( 1 downto 0);
      Dcr_Read_Data                   : out std_logic_vector(31 downto 0);

      -- Reference Clock, PGP Clock & Reset Signals
      -- Use one ref clock, tie other to 0, see RefClkSel above
      pgpRefClk1                      : in  std_logic;
      pgpRefClk2                      : in  std_logic;
      pgpClk                          : in  std_logic;
      pgpReset                        : in  std_logic;

      -- MGT Serial Pins
      mgtRxN                          : in  std_logic_vector(3 downto 0);
      mgtRxP                          : in  std_logic_vector(3 downto 0);
      mgtTxN                          : out std_logic_vector(3 downto 0);
      mgtTxP                          : out std_logic_vector(3 downto 0)
   );
end Pgp2Rce4x;


-- Define architecture
architecture Pgp2Rce4x of Pgp2Rce4x is

   -- Local Signals
   signal vcFrameTxVc      : std_logic_vector(1 downto 0);
   signal vcFrameTxSOF     : std_logic;
   signal vcFrameTxEOF     : std_logic;
   signal vcFrameTxEOFE    : std_logic;
   signal vcFrameTxData    : std_logic_vector(15 downto 0);
   signal vcFrameTxValid   : std_logic_vector(3  downto 0);
   signal vcFrameTxReady   : std_logic_vector(3  downto 0);
   signal vcRemBuffAFull   : std_logic_vector(15 downto 0);
   signal vcRemBuffFull    : std_logic_vector(15 downto 0);
   signal vcFrameRxSOF     : std_logic_vector(3  downto 0);
   signal vcFrameRxEOF     : std_logic_vector(3  downto 0);
   signal vcFrameRxEOFE    : std_logic_vector(3  downto 0);
   signal vcFrameRxDataA   : std_logic_vector(63 downto 0);
   signal vcFrameRxDataB   : std_logic_vector(63 downto 0);
   signal vcFrameRxDataC   : std_logic_vector(63 downto 0);
   signal vcFrameRxDataD   : std_logic_vector(63 downto 0);
   signal vcFrameRxReq     : std_logic_vector(3  downto 0);
   signal vcFrameRxValid   : std_logic_vector(3  downto 0);
   signal vcFrameRxReady   : std_logic_vector(3  downto 0);
   signal vcFrameRxWidthA  : std_logic_vector(1  downto 0);
   signal vcFrameRxWidthB  : std_logic_vector(1  downto 0);
   signal vcFrameRxWidthC  : std_logic_vector(1  downto 0);
   signal vcFrameRxWidthD  : std_logic_vector(1  downto 0);
   signal pgpRemLinkReady  : std_logic_vector(3  downto 0);
   signal pgpLocLinkReady  : std_logic_vector(3  downto 0);
   signal cntReset         : std_logic;
   signal pgpCntCellErrorA : std_logic_vector(3 downto 0);
   signal pgpCntCellErrorB : std_logic_vector(3 downto 0);
   signal pgpCntCellErrorC : std_logic_vector(3 downto 0);
   signal pgpCntCellErrorD : std_logic_vector(3 downto 0);
   signal pgpCntLinkDownA  : std_logic_vector(3 downto 0);
   signal pgpCntLinkDownB  : std_logic_vector(3 downto 0);
   signal pgpCntLinkDownC  : std_logic_vector(3 downto 0);
   signal pgpCntLinkDownD  : std_logic_vector(3 downto 0);
   signal pgpCntLinkErrorA : std_logic_vector(3 downto 0);
   signal pgpCntLinkErrorB : std_logic_vector(3 downto 0);
   signal pgpCntLinkErrorC : std_logic_vector(3 downto 0);
   signal pgpCntLinkErrorD : std_logic_vector(3 downto 0);
   signal pgpRxFifoErr     : std_logic_vector(3 downto 0);
   signal mgtLoopback      : std_logic_vector(3 downto 0);
   signal mgtCombusOutA    : std_logic_vector(15 downto 0);
   signal mgtCombusOutB    : std_logic_vector(15 downto 0);
   signal mgtCombusOutC    : std_logic_vector(15 downto 0);
   signal mgtCombusOutD    : std_logic_vector(15 downto 0);
   signal pllTxRst         : std_logic_vector(3  downto 0);
   signal pllRxRst         : std_logic_vector(3  downto 0);
   signal pllTxReady       : std_logic_vector(3  downto 0);
   signal pllRxReady       : std_logic_vector(3  downto 0);
   signal dcrReset         : std_logic;                     
   signal dcrResetSync     : std_logic;                     
   signal writeData        : std_logic_vector(31 downto 0); 
   signal writeDataSync    : std_logic_vector(31 downto 0); 
   signal csControl0       : std_logic_vector(35 downto 0);
   signal csControl1       : std_logic_vector(35 downto 0);
   signal csData           : std_logic_vector(63 downto 0);
   signal csCntrl          : std_logic_vector(15 downto 0);
   signal csStat           : std_logic_vector(15 downto 0);
   signal importDebug      : std_logic_vector(63 downto 0);
   signal exportDebug      : std_logic_vector(63 downto 0);
   signal lane0Debug       : std_logic_vector(63 downto 0);
   signal lane1Debug       : std_logic_vector(63 downto 0);
   signal importReset      : std_logic_vector(3  downto 0);
   signal pgpRxCntD        : std_logic_vector(3  downto 0);
   signal pgpRxCntC        : std_logic_vector(3  downto 0);
   signal pgpRxCntB        : std_logic_vector(3  downto 0);
   signal pgpRxCntA        : std_logic_vector(3  downto 0);

   -- ICON
   component pgp2_v4_icon
     PORT (
       CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
       CONTROL1 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
   end component;

   -- ILA
   component pgp2_v4_ila
     PORT (
       CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
       CLK : IN STD_LOGIC;
       DATA : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
       TRIG0 : IN STD_LOGIC_VECTOR(7 DOWNTO 0));
   end component;

   -- VIO
   component pgp2_v4_vio
     PORT (
       CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
       CLK : IN STD_LOGIC;
       SYNC_IN : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
       SYNC_OUT : OUT STD_LOGIC_VECTOR(15 DOWNTO 0));
   end component;

   -- Chipscope attributes
   attribute syn_black_box : boolean;
   attribute syn_noprune   : boolean;
   attribute syn_black_box of pgp2_v4_icon : component is TRUE;
   attribute syn_noprune   of pgp2_v4_icon : component is TRUE;
   attribute syn_black_box of pgp2_v4_ila  : component is TRUE;
   attribute syn_noprune   of pgp2_v4_ila  : component is TRUE;
   attribute syn_black_box of pgp2_v4_vio  : component is TRUE;
   attribute syn_noprune   of pgp2_v4_vio  : component is TRUE;

   -- Register delay for simulation
   constant tpd:time := 0.5 ns;

begin

   -- Create import reset vector
   importReset <= Import_Core_Reset & Import_Core_Reset & Import_Core_Reset & Import_Core_Reset;

   -- Dcr Reset generation, Sync to DCR Clock
   process ( Dcr_Clock ) begin
      if rising_edge(Dcr_Clock) then
         dcrResetSync <= pgpReset     after tpd;
         dcrReset     <= dcrResetSync after tpd;
      end if;
   end process;


   -- DCR Read
   process ( dcrReset, Dcr_Clock ) begin
      if dcrReset = '1' then
         Dcr_Read_Data <= (others=>'0') after tpd;
      elsif rising_edge(Dcr_Clock) then
         case Dcr_Read_Address is 
            when "00"  => 
               Dcr_Read_Data(31 downto 28) <= pgpRemLinkReady  after tpd;
               Dcr_Read_Data(27 downto 24) <= pgpLocLinkReady  after tpd;
               Dcr_Read_Data(23 downto 20) <= pllTxReady       after tpd;
               Dcr_Read_Data(19 downto 16) <= pllRxReady       after tpd;
               Dcr_Read_Data(15 downto 13) <= (others=>'0')    after tpd;
               Dcr_Read_Data(12)           <= cntReset         after tpd;
               Dcr_Read_Data(11 downto  8) <= pllTxRst         after tpd;
               Dcr_Read_Data(7  downto  4) <= pllRxRst         after tpd;
               Dcr_Read_Data(3  downto  0) <= mgtLoopback      after tpd;
            when "01"  => 
               Dcr_Read_Data(31 downto 28) <= pgpCntCellErrorD after tpd;
               Dcr_Read_Data(27 downto 24) <= pgpCntCellErrorC after tpd;
               Dcr_Read_Data(23 downto 20) <= pgpCntCellErrorB after tpd;
               Dcr_Read_Data(19 downto 16) <= pgpCntCellErrorA after tpd;
               Dcr_Read_Data(15 downto 12) <= pgpCntLinkErrorD after tpd;
               Dcr_Read_Data(11 downto  8) <= pgpCntLinkErrorC after tpd;
               Dcr_Read_Data( 7 downto  4) <= pgpCntLinkErrorB after tpd;
               Dcr_Read_Data( 3 downto  0) <= pgpCntLinkErrorA after tpd;
            when "10"  => 
               Dcr_Read_Data(31 downto 20) <= (others=>'0')    after tpd;
               Dcr_Read_Data(19 downto 16) <= pgpRxFifoErr     after tpd;
               Dcr_Read_Data(15 downto 12) <= pgpCntLinkDownD  after tpd;
               Dcr_Read_Data(11 downto  8) <= pgpCntLinkDownC  after tpd;
               Dcr_Read_Data( 7 downto  4) <= pgpCntLinkDownB  after tpd;
               Dcr_Read_Data( 3 downto  0) <= pgpCntLinkDownA  after tpd;
            when "11"  => 
               Dcr_Read_Data(31 downto 16) <= (others=>'0')    after tpd;
               Dcr_Read_Data(15 downto 12) <= pgpRxCntD        after tpd;
               Dcr_Read_Data(11 downto  8) <= pgpRxCntC        after tpd;
               Dcr_Read_Data( 7 downto  4) <= pgpRxCntB        after tpd;
               Dcr_Read_Data( 3 downto  0) <= pgpRxCntA        after tpd;
            when others => 
               Dcr_Read_Data               <= (others=>'0')    after tpd;
         end case;
      end if;
   end process;


   -- DCR Write
   process ( dcrReset, Dcr_Clock ) begin
      if dcrReset = '1' then
         writeData <= (others=>'0') after tpd;
      elsif rising_edge(Dcr_Clock) then
         if Dcr_Write = '1' then
            writeData <= Dcr_Write_Data after tpd;
         end if;
      end if;
   end process;


   -- Synchronize Write Data
   process ( pgpReset, pgpClk ) begin
      if pgpReset = '1' then
         writeDataSync <= (others=>'0') after tpd;
         cntReset      <= '0'           after tpd;
         pllTxRst      <= (others=>'0') after tpd;
         pllRxRst      <= (others=>'0') after tpd;
         mgtLoopback   <= (others=>'0') after tpd;
      elsif rising_edge(pgpClk) then
         writeDataSync <= writeData                                                             after tpd;
         cntReset      <= writeDataSync(12)           or csCntrl(12)          or importReset(0) after tpd;
         pllTxRst      <= writeDataSync(11 downto  8) or csCntrl(3  downto 0)                   after tpd;
         pllRxRst      <= writeDataSync(7  downto  4) or csCntrl(7  downto 4) or importReset    after tpd;
         mgtLoopback   <= writeDataSync(3  downto  0) or csCntrl(11 downto 8)                   after tpd;
      end if;
   end process;


   -- Export Interface
   U_Pgp2RceExport: Pgp2RcePackage.Pgp2RceExport port map ( 
      pgpClk                         => pgpClk,
      pgpReset                       => pgpReset,
      Export_Clock                   => Export_Clock,
      Export_Core_Reset              => Export_Core_Reset,
      Export_Data_Available          => Export_Data_Available,
      Export_Data_Start              => Export_Data_Start,
      Export_Advance_Data_Pipeline   => Export_Advance_Data_Pipeline,
      Export_Data_Last_Line          => Export_Data_Last_Line,
      Export_Data_Last_Valid_Byte    => Export_Data_Last_Valid_Byte,
      Export_Data                    => Export_Data,
      Export_Advance_Status_Pipeline => Export_Advance_Status_Pipeline,
      Export_Status                  => Export_Status,
      Export_Status_Full             => Export_Status_Full,
      pgpRemLinkReady                => pgpRemLinkReady,
      vcFrameTxVc                    => vcFrameTxVc,
      vcFrameTxSOF                   => vcFrameTxSOF,
      vcFrameTxEOF                   => vcFrameTxEOF,
      vcFrameTxEOFE                  => vcFrameTxEOFE,
      vcFrameTxData                  => vcFrameTxData,
      vcFrameTxValid                 => vcFrameTxValid,
      vcFrameTxReady                 => vcFrameTxReady,
      vcRemBuffAFull                 => vcRemBuffAFull,
      vcRemBuffFull                  => vcRemBuffFull,
      debug                          => exportDebug
   );


   -- Import Interface
   U_Pgp2RceImport: Pgp2RcePackage.Pgp2RceImport 
      generic map (
         FreeListA => FreeListA,
         FreeListB => FreeListB,
         FreeListC => FreeListC,
         FreeListD => FreeListD 
      ) port map (
         pgpClk                       => pgpClk,
         pgpReset                     => pgpReset,
         Import_Clock                 => Import_Clock,
         Import_Core_Reset            => Import_Core_Reset,
         Import_Free_List             => Import_Free_List,
         Import_Advance_Data_Pipeline => Import_Advance_Data_Pipeline,
         Import_Data_Last_Line        => Import_Data_Last_Line,
         Import_Data_Last_Valid_Byte  => Import_Data_Last_Valid_Byte,
         Import_Data                  => Import_Data,
         Import_Data_Pipeline_Full    => Import_Data_Pipeline_Full,
         Import_Pause                 => Import_Pause,
         pgpLocLinkReady              => pgpLocLinkReady,
         vcFrameRxSOF                 => vcFrameRxSOF,
         vcFrameRxEOF                 => vcFrameRxEOF,
         vcFrameRxEOFE                => vcFrameRxEOFE,
         vcFrameRxDataA               => vcFrameRxDataA,
         vcFrameRxDataB               => vcFrameRxDataB,
         vcFrameRxDataC               => vcFrameRxDataC,
         vcFrameRxDataD               => vcFrameRxDataD,
         vcFrameRxReq                 => vcFrameRxReq,
         vcFrameRxValid               => vcFrameRxValid,
         vcFrameRxReady               => vcFrameRxReady,
         vcFrameRxWidthA              => vcFrameRxWidthA,
         vcFrameRxWidthB              => vcFrameRxWidthB,
         vcFrameRxWidthC              => vcFrameRxWidthC,
         vcFrameRxWidthD              => vcFrameRxWidthD,
         debug                        => importDebug
      );


   -- Lane A
   U_Pgp2RceLaneA: Pgp2RcePackage.Pgp2RceLane 
      generic map (
         MgtMode   => "A",
         RefClkSel => RefClkSel
      ) port map ( 
         pgpClk            => pgpClk,
         pgpReset          => pgpReset,
         pllTxRst          => pllTxRst(0),
         pllRxRst          => pllRxRst(0),
         pllRxReady        => pllRxReady(0),
         pllTxReady        => pllTxReady(0),
         pgpLocLinkReady   => pgpLocLinkReady(0),
         pgpRemLinkReady   => pgpRemLinkReady(0),
         cntReset          => cntReset,
         pgpCntCellError   => pgpCntCellErrorA,
         pgpCntLinkDown    => pgpCntLinkDownA,
         pgpCntLinkError   => pgpCntLinkErrorA,
         pgpRxFifoErr      => pgpRxFifoErr(0),
         pgpRxCnt          => pgpRxCntA,
         laneNumber        => "00",
         vcFrameRxSOF      => vcFrameRxSOF(0),
         vcFrameRxEOF      => vcFrameRxEOF(0),
         vcFrameRxEOFE     => vcFrameRxEOFE(0),
         vcFrameRxData     => vcFrameRxDataA,
         vcFrameRxReq      => vcFrameRxReq(0),
         vcFrameRxValid    => vcFrameRxValid(0),
         vcFrameRxReady    => vcFrameRxReady(0),
         vcFrameRxWidth    => vcFrameRxWidthA,
         vcFrameTxVc       => vcFrameTxVc,
         vcFrameTxValid    => vcFrameTxValid(0),
         vcFrameTxReady    => vcFrameTxReady(0),
         vcFrameTxSOF      => vcFrameTxSOF,
         vcFrameTxEOF      => vcFrameTxEOF,
         vcFrameTxEOFE     => vcFrameTxEOFE,
         vcFrameTxData     => vcFrameTxData,
         vcRemBuffAFull    => vcRemBuffAFull(3 downto 0),
         vcRemBuffFull     => vcRemBuffFull(3 downto 0),
         mgtLoopback       => mgtLoopback(0),
         mgtRefClk1        => pgpRefClk1,
         mgtRefClk2        => pgpRefClk2,
         mgtRxN            => mgtRxN(0),
         mgtRxP            => mgtRxP(0),
         mgtTxN            => mgtTxN(0),
         mgtTxP            => mgtTxP(0),
         mgtCombusIn       => mgtCombusOutB,
         mgtCombusOut      => mgtCombusOutA,
         debug             => lane0Debug
      );


   -- Lane B
   U_Pgp2RceLaneB: Pgp2RcePackage.Pgp2RceLane 
      generic map (
         MgtMode   => "B",
         RefClkSel => RefClkSel
      ) port map ( 
         pgpClk            => pgpClk,
         pgpReset          => pgpReset,
         pllTxRst          => pllTxRst(1),
         pllRxRst          => pllRxRst(1),
         pllRxReady        => pllRxReady(1),
         pllTxReady        => pllTxReady(1),
         pgpLocLinkReady   => pgpLocLinkReady(1),
         pgpRemLinkReady   => pgpRemLinkReady(1),
         cntReset          => cntReset,
         pgpCntCellError   => pgpCntCellErrorB,
         pgpCntLinkDown    => pgpCntLinkDownB,
         pgpCntLinkError   => pgpCntLinkErrorB,
         pgpRxFifoErr      => pgpRxFifoErr(1),
         pgpRxCnt          => pgpRxCntB,
         laneNumber        => "01",
         vcFrameRxSOF      => vcFrameRxSOF(1),
         vcFrameRxEOF      => vcFrameRxEOF(1),
         vcFrameRxEOFE     => vcFrameRxEOFE(1),
         vcFrameRxData     => vcFrameRxDataB,
         vcFrameRxReq      => vcFrameRxReq(1),
         vcFrameRxValid    => vcFrameRxValid(1),
         vcFrameRxReady    => vcFrameRxReady(1),
         vcFrameRxWidth    => vcFrameRxWidthB,
         vcFrameTxVc       => vcFrameTxVc,
         vcFrameTxValid    => vcFrameTxValid(1),
         vcFrameTxReady    => vcFrameTxReady(1),
         vcFrameTxSOF      => vcFrameTxSOF,
         vcFrameTxEOF      => vcFrameTxEOF,
         vcFrameTxEOFE     => vcFrameTxEOFE,
         vcFrameTxData     => vcFrameTxData,
         vcRemBuffAFull    => vcRemBuffAFull(7 downto 4),
         vcRemBuffFull     => vcRemBuffFull(7 downto 4),
         mgtLoopback       => mgtLoopback(1),
         mgtRefClk1        => pgpRefClk1,
         mgtRefClk2        => pgpRefClk2,
         mgtRxN            => mgtRxN(1),
         mgtRxP            => mgtRxP(1),
         mgtTxN            => mgtTxN(1),
         mgtTxP            => mgtTxP(1),
         mgtCombusIn       => mgtCombusOutA,
         mgtCombusOut      => mgtCombusOutB,
         debug             => lane1Debug
      );


   -- Lane C
   U_Pgp2RceLaneC: Pgp2RcePackage.Pgp2RceLane 
      generic map (
         MgtMode   => "A",
         RefClkSel => RefClkSel
      ) port map ( 
         pgpClk            => pgpClk,
         pgpReset          => pgpReset,
         pllTxRst          => pllTxRst(2),
         pllRxRst          => pllRxRst(2),
         pllRxReady        => pllRxReady(2),
         pllTxReady        => pllTxReady(2),
         pgpLocLinkReady   => pgpLocLinkReady(2),
         pgpRemLinkReady   => pgpRemLinkReady(2),
         cntReset          => cntReset,
         pgpCntCellError   => pgpCntCellErrorC,
         pgpCntLinkDown    => pgpCntLinkDownC,
         pgpCntLinkError   => pgpCntLinkErrorC,
         pgpRxFifoErr      => pgpRxFifoErr(2),
         pgpRxCnt          => pgpRxCntC,
         laneNumber        => "10",
         vcFrameRxSOF      => vcFrameRxSOF(2),
         vcFrameRxEOF      => vcFrameRxEOF(2),
         vcFrameRxEOFE     => vcFrameRxEOFE(2),
         vcFrameRxData     => vcFrameRxDataC,
         vcFrameRxReq      => vcFrameRxReq(2),
         vcFrameRxValid    => vcFrameRxValid(2),
         vcFrameRxReady    => vcFrameRxReady(2),
         vcFrameRxWidth    => vcFrameRxWidthC,
         vcFrameTxVc       => vcFrameTxVc,
         vcFrameTxValid    => vcFrameTxValid(2),
         vcFrameTxReady    => vcFrameTxReady(2),
         vcFrameTxSOF      => vcFrameTxSOF,
         vcFrameTxEOF      => vcFrameTxEOF,
         vcFrameTxEOFE     => vcFrameTxEOFE,
         vcFrameTxData     => vcFrameTxData,
         vcRemBuffAFull    => vcRemBuffAFull(11 downto 8),
         vcRemBuffFull     => vcRemBuffFull(11 downto 8),
         mgtLoopback       => mgtLoopback(2),
         mgtRefClk1        => pgpRefClk1,
         mgtRefClk2        => pgpRefClk2,
         mgtRxN            => mgtRxN(2),
         mgtRxP            => mgtRxP(2),
         mgtTxN            => mgtTxN(2),
         mgtTxP            => mgtTxP(2),
         mgtCombusIn       => mgtCombusOutD,
         mgtCombusOut      => mgtCombusOutC,
         debug             => open
      );


   -- Lane D
   U_Pgp2RceLaneD: Pgp2RcePackage.Pgp2RceLane 
      generic map (
         MgtMode   => "B",
         RefClkSel => RefClkSel
      ) port map ( 
         pgpClk            => pgpClk,
         pgpReset          => pgpReset,
         pllTxRst          => pllTxRst(3),
         pllRxRst          => pllRxRst(3),
         pllRxReady        => pllRxReady(3),
         pllTxReady        => pllTxReady(3),
         pgpLocLinkReady   => pgpLocLinkReady(3),
         pgpRemLinkReady   => pgpRemLinkReady(3),
         cntReset          => cntReset,
         pgpCntCellError   => pgpCntCellErrorD,
         pgpCntLinkDown    => pgpCntLinkDownD,
         pgpCntLinkError   => pgpCntLinkErrorD,
         pgpRxFifoErr      => pgpRxFifoErr(3),
         pgpRxCnt          => pgpRxCntD,
         laneNumber        => "11",
         vcFrameRxSOF      => vcFrameRxSOF(3),
         vcFrameRxEOF      => vcFrameRxEOF(3),
         vcFrameRxEOFE     => vcFrameRxEOFE(3),
         vcFrameRxData     => vcFrameRxDataD,
         vcFrameRxReq      => vcFrameRxReq(3),
         vcFrameRxValid    => vcFrameRxValid(3),
         vcFrameRxReady    => vcFrameRxReady(3),
         vcFrameRxWidth    => vcFrameRxWidthD,
         vcFrameTxVc       => vcFrameTxVc,
         vcFrameTxValid    => vcFrameTxValid(3),
         vcFrameTxReady    => vcFrameTxReady(3),
         vcFrameTxSOF      => vcFrameTxSOF,
         vcFrameTxEOF      => vcFrameTxEOF,
         vcFrameTxEOFE     => vcFrameTxEOFE,
         vcFrameTxData     => vcFrameTxData,
         vcRemBuffAFull    => vcRemBuffAFull(15 downto 12),
         vcRemBuffFull     => vcRemBuffFull(15 downto 12),
         mgtLoopback       => mgtLoopback(3),
         mgtRefClk1        => pgpRefClk1,
         mgtRefClk2        => pgpRefClk2,
         mgtRxN            => mgtRxN(3),
         mgtRxP            => mgtRxP(3),
         mgtTxN            => mgtTxN(3),
         mgtTxP            => mgtTxP(3),
         mgtCombusIn       => mgtCombusOutC,
         mgtCombusOut      => mgtCombusOutD,
         debug             => open
      );
   -----------------------------
   -- Debug
   -----------------------------

   U_icon : pgp2_v4_icon port map ( 
      CONTROL0 => csControl0,
      CONTROL1 => csControl1
   );

   U_ila : pgp2_v4_ila port map (
      CONTROL => csControl0,
      CLK     => pgpClk,
      DATA    => csData,
      TRIG0   => csData(7 downto 0)
   );

   U_vio : pgp2_v4_vio port map (
       CONTROL  => csControl1,
       CLK      => pgpClk,
       SYNC_IN  => csStat,
       SYNC_OUT => csCntrl
   );

   -- Status Bits
   csStat(15 downto 4) <= (others=>'0');
   csStat(3  downto 2) <= pgpRemLinkReady(1 downto 0);
   csStat(1  downto 0) <= pgpLocLinkReady(1 downto 0);

   -- Control Bits
   -- cntReset      csCntrl(12)
   -- pllTxRst      csCntrl(3  downto 0)
   -- pllRxRst      csCntrl(7  downto 4)
   -- mgtLoopback   csCntrl(11 downto 8)

   csData <= importDebug when csCntrl(15 downto 14) = "00" else
             exportDebug when csCntrl(15 downto 14) = "01" else
             lane0Debug  when csCntrl(15 downto 14) = "10" else
             lane1Debug;

end Pgp2Rce4x;

