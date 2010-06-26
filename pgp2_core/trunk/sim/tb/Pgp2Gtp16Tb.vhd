-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, Top Level PGP + GTP Test Bench
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Gtp16Tb.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 05/27/2009
-------------------------------------------------------------------------------
-- Description:
-- Test Bench for PGP core plus Xilinx GTP
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 05/27/2009: created.
-------------------------------------------------------------------------------

LIBRARY ieee;
USE work.ALL;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.Pgp2GtpPackage.all;
Library unisim;
use unisim.vcomponents.all;

entity Pgp2Gtp16Tb is end Pgp2Gtp16Tb;


-- Define architecture
architecture Pgp2Gtp16Tb of Pgp2Gtp16Tb is

   component Pgp2VcTest
      port (
         pgpRxClk          : in  std_logic;
         pgpRxRst          : in  std_logic;
         pgpTxClk          : in  std_logic;
         pgpTxRst          : in  std_logic;
         pgpLinkReady      : in  std_logic;
         vcTxValid         : out std_logic;
         vcTxReady         : in  std_logic;
         vcTxSOF           : out std_logic;
         vcTxEOF           : out std_logic;
         vcTxEOFE          : out std_logic;
         vcTxDataLow       : out std_logic_vector(31 downto 0);
         vcTxDataHigh      : out std_logic_vector(31 downto 0);
         vcLocBuffAFull    : out std_logic;
         vcLocBuffFull     : out std_logic;
         vcRxSOF           : in  std_logic;
         vcRxEOF           : in  std_logic;
         vcRxEOFE          : in  std_logic;
         vcRxDataLow       : in  std_logic_vector(31 downto 0);
         vcRxDataHigh      : in  std_logic_vector(31 downto 0);
         vcRxValid         : in  std_logic;
         vcRemBuffAFull    : in  std_logic;
         vcRemBuffFull     : in  std_logic;
         vcWidth           : in  std_logic_vector(1 downto 0);
         vcNum             : in  std_logic_vector(1 downto 0)
      );
   end component;

   -- Internal signals
   signal pgpClk            : std_logic;
   signal pgpClk2x          : std_logic;
   signal pgpReset          : std_logic;
   signal pgpLocLinkReady   : std_logic;
   signal pgpRemLinkReady   : std_logic;
   signal pgpLinkReady      : std_logic;
   signal vc0FrameTxValid   : std_logic;
   signal vc0FrameTxReady   : std_logic;
   signal vc0FrameTxSOF     : std_logic;
   signal vc0FrameTxEOF     : std_logic;
   signal vc0FrameTxEOFE    : std_logic;
   signal vc0FrameTxData    : std_logic_vector(15 downto 0);
   signal vc1FrameTxValid   : std_logic;
   signal vc1FrameTxReady   : std_logic;
   signal vc1FrameTxSOF     : std_logic;
   signal vc1FrameTxEOF     : std_logic;
   signal vc1FrameTxEOFE    : std_logic;
   signal vc1FrameTxData    : std_logic_vector(15 downto 0);
   signal vc2FrameTxValid   : std_logic;
   signal vc2FrameTxReady   : std_logic;
   signal vc2FrameTxSOF     : std_logic;
   signal vc2FrameTxEOF     : std_logic;
   signal vc2FrameTxEOFE    : std_logic;
   signal vc2FrameTxData    : std_logic_vector(15 downto 0);
   signal vc3FrameTxValid   : std_logic;
   signal vc3FrameTxReady   : std_logic;
   signal vc3FrameTxSOF     : std_logic;
   signal vc3FrameTxEOF     : std_logic;
   signal vc3FrameTxEOFE    : std_logic;
   signal vc3FrameTxData    : std_logic_vector(15 downto 0);
   signal vcFrameRxSOF      : std_logic;
   signal vcFrameRxEOF      : std_logic;
   signal vcFrameRxEOFE     : std_logic;
   signal vcFrameRxData     : std_logic_vector(15 downto 0);
   signal vc0FrameRxValid   : std_logic;
   signal vc1FrameRxValid   : std_logic;
   signal vc2FrameRxValid   : std_logic;
   signal vc3FrameRxValid   : std_logic;
   signal vc0RemBuffAFull   : std_logic;
   signal vc0RemBuffFull    : std_logic;
   signal vc1RemBuffAFull   : std_logic;
   signal vc1RemBuffFull    : std_logic;
   signal vc2RemBuffAFull   : std_logic;
   signal vc2RemBuffFull    : std_logic;
   signal vc3RemBuffAFull   : std_logic;
   signal vc3RemBuffFull    : std_logic;
   signal vc0LocBuffAFull   : std_logic;
   signal vc0LocBuffFull    : std_logic;
   signal vc1LocBuffAFull   : std_logic;
   signal vc1LocBuffFull    : std_logic;
   signal vc2LocBuffAFull   : std_logic;
   signal vc2LocBuffFull    : std_logic;
   signal vc3LocBuffAFull   : std_logic;
   signal vc3LocBuffFull    : std_logic;
   signal gtpRxN            : std_logic;
   signal gtpRxP            : std_logic;
   signal refClk            : std_logic;
   signal refClkOut         : std_logic;
   signal ponRstL           : std_logic;
   signal pgpTxOpCodeEn     : std_logic;
   signal pgpTxOpCode       : std_logic_vector(7 downto 0);
   signal pgpRxOpCodeEn     : std_logic;
   signal pgpRxOpCode       : std_logic_vector(7 downto 0);

begin


   -- Power On Reset generation
   process 
   begin
      ponRstL  <= '1';
      wait for (6.4 ns);
      ponRstL  <= '0';
      wait for (6.4 ns * 20);
      ponRstL  <= '1';
      wait;
   end process;

   -- 156.25Mhz Reference Clock generation
   process 
   begin
      refClk <= '0';
      wait for (6.4 ns / 2);
      refClk <= '1';
      wait for (6.4 ns / 2);
   end process;


   -- PGP Clock Block
   U_Pgp2GtpClk: Pgp2GtpPackage.Pgp2GtpClk generic map (
      UserFxDiv  => 5,
      UserFxMult => 4
   ) port map (
      pgpRefClk     => refClkOut,
      ponResetL     => ponRstL,
      locReset      => '0',
      pgpClk        => pgpClk,
      pgpReset      => pgpReset,
      pgpClk2x      => pgpClk2x,
      userClk       => open,
      userReset     => open,
      pgpClkIn      => pgpClk,
      userClkIn     => '0'
   );


   -- PGP
   U_Pgp2Gtp16: Pgp2GtpPackage.Pgp2Gtp16 generic map (
         EnShortCells => 0,
         VcInterleave => 1
      ) port map (
         pgpClk            => pgpClk,
         pgpReset          => pgpReset,
         pgpClk2x          => pgpClk2x,
         pllTxRst          => '0',
         pllRxRst          => '0',
         pgpRemData        => open,
         pgpLocData        => (others=>'0'),
         pgpTxOpCodeEn     => pgpTxOpCodeEn,
         pgpTxOpCode       => pgpTxOpCode,
         pgpRxOpCodeEn     => pgpRxOpCodeEn,
         pgpRxOpCode       => pgpRxOpCode,
         pgpLocLinkReady   => pgpLocLinkReady,
         pgpRemLinkReady   => pgpRemLinkReady,
         pgpRxCellError    => open,
         pgpRxLinkDown     => open,
         pgpRxLinkError    => open,
         vc0FrameTxValid   => vc0FrameTxValid,
         vc0FrameTxReady   => vc0FrameTxReady,
         vc0FrameTxSOF     => vc0FrameTxSOF,
         vc0FrameTxEOF     => vc0FrameTxEOF,
         vc0FrameTxEOFE    => vc0FrameTxEOFE,
         vc0FrameTxData    => vc0FrameTxData,
         vc0LocBuffAFull   => vc0LocBuffAFull,
         vc0LocBuffFull    => vc0LocBuffFull,
         vc1FrameTxValid   => vc1FrameTxValid,
         vc1FrameTxReady   => vc1FrameTxReady,
         vc1FrameTxSOF     => vc1FrameTxSOF,
         vc1FrameTxEOF     => vc1FrameTxEOF,
         vc1FrameTxEOFE    => vc1FrameTxEOFE,
         vc1FrameTxData    => vc1FrameTxData,
         vc1LocBuffAFull   => vc1LocBuffAFull,
         vc1LocBuffFull    => vc1LocBuffFull,
         vc2FrameTxValid   => vc2FrameTxValid,
         vc2FrameTxReady   => vc2FrameTxReady,
         vc2FrameTxSOF     => vc2FrameTxSOF,
         vc2FrameTxEOF     => vc2FrameTxEOF,
         vc2FrameTxEOFE    => vc2FrameTxEOFE,
         vc2FrameTxData    => vc2FrameTxData,
         vc2LocBuffAFull   => vc2LocBuffAFull,
         vc2LocBuffFull    => vc2LocBuffFull,
         vc3FrameTxValid   => vc3FrameTxValid,
         vc3FrameTxReady   => vc3FrameTxReady,
         vc3FrameTxSOF     => vc3FrameTxSOF,
         vc3FrameTxEOF     => vc3FrameTxEOF,
         vc3FrameTxEOFE    => vc3FrameTxEOFE,
         vc3FrameTxData    => vc3FrameTxData,
         vc3LocBuffAFull   => vc3LocBuffAFull,
         vc3LocBuffFull    => vc3LocBuffFull,
         vcFrameRxSOF      => vcFrameRxSOF,
         vcFrameRxEOF      => vcFrameRxEOF,
         vcFrameRxEOFE     => vcFrameRxEOFE,
         vcFrameRxData     => vcFrameRxData,
         vc0FrameRxValid   => vc0FrameRxValid,
         vc0RemBuffAFull   => vc0RemBuffAFull,
         vc0RemBuffFull    => vc0RemBuffFull,
         vc1FrameRxValid   => vc1FrameRxValid,
         vc1RemBuffAFull   => vc1RemBuffAFull,
         vc1RemBuffFull    => vc1RemBuffFull,
         vc2FrameRxValid   => vc2FrameRxValid,
         vc2RemBuffAFull   => vc2RemBuffAFull,
         vc2RemBuffFull    => vc2RemBuffFull,
         vc3FrameRxValid   => vc3FrameRxValid,
         vc3RemBuffAFull   => vc3RemBuffAFull,
         vc3RemBuffFull    => vc3RemBuffFull,
         gtpLoopback       =>'0',
         gtpClkIn          => refClk,
         gtpRefClkOut      => refClkOut,
         gtpRxRecClk       => open,
         gtpRxN            => gtpRxN, 
         gtpRxP            => gtpRxP, 
         gtpTxN            => gtpRxN, 
         gtpTxP            => gtpRxP 
      );


   process begin
      pgpTxOpCodeEn <= '0';
      wait until pgpLinkReady = '1';
      wait for (1.1 us);
      wait until falling_edge(pgpClk);
      pgpTxOpCodeEn <= '1';
      wait until falling_edge(pgpClk);
   end process;
   pgpTxOpCode <= x"4A";

   -- Link is ready
   pgpLinkReady <= pgpLocLinkReady and pgpRemLinkReady;


   -- VC0 Model
   U_Pgp2Vc0Test: Pgp2VcTest port map (
      pgpRxClk                  => pgpClk,
      pgpRxRst                  => pgpReset,
      pgpTxClk                  => pgpClk,
      pgpTxRst                  => pgpReset,
      pgpLinkReady              => pgpLinkReady,
      vcTxValid                 => vc0FrameTxValid,
      vcTxReady                 => vc0FrameTxReady,
      vcTxSOF                   => vc0FrameTxSOF,
      vcTxEOF                   => vc0FrameTxEOF,
      vcTxEOFE                  => vc0FrameTxEOFE,
      vcTxDataLow(15 downto  0) => vc0FrameTxData,
      vcTxDataLow(31 downto 16) => open,
      vcTxDataHigh              => open,
      vcLocBuffAFull            => vc0LocBuffAFull,
      vcLocBuffFull             => vc0LocBuffFull,
      vcRxSOF                   => vcFrameRxSOF,
      vcRxEOF                   => vcFrameRxEOF,
      vcRxEOFE                  => vcFrameRxEOFE,
      vcRxDataLow(15 downto  0) => vcFrameRxData,
      vcRxDataLow(31 downto 16) => (others=>'0'),
      vcRxDataHigh              => (others=>'0'),
      vcRxValid                 => vc0FrameRxValid,
      vcRemBuffAFull            => vc0RemBuffAFull,
      vcRemBuffFull             => vc0RemBuffFull,
      vcWidth                   => "00",
      vcNum                     => "00"
   );


   -- VC1 Model
   U_Pgp2Vc1Test: Pgp2VcTest port map (
      pgpRxClk                  => pgpClk,
      pgpRxRst                  => pgpReset,
      pgpTxClk                  => pgpClk,
      pgpTxRst                  => pgpReset,
      pgpLinkReady              => pgpLinkReady,
      vcTxValid                 => vc1FrameTxValid,
      vcTxReady                 => vc1FrameTxReady,
      vcTxSOF                   => vc1FrameTxSOF,
      vcTxEOF                   => vc1FrameTxEOF,
      vcTxEOFE                  => vc1FrameTxEOFE,
      vcTxDataLow(15 downto  0) => vc1FrameTxData,
      vcTxDataLow(31 downto 16) => open,
      vcTxDataHigh              => open,
      vcLocBuffAFull            => vc1LocBuffAFull,
      vcLocBuffFull             => vc1LocBuffFull,
      vcRxSOF                   => vcFrameRxSOF,
      vcRxEOF                   => vcFrameRxEOF,
      vcRxEOFE                  => vcFrameRxEOFE,
      vcRxDataLow(15 downto  0) => vcFrameRxData,
      vcRxDataLow(31 downto 16) => (others=>'0'),
      vcRxDataHigh              => (others=>'0'),
      vcRxValid                 => vc1FrameRxValid,
      vcRemBuffAFull            => vc1RemBuffAFull,
      vcRemBuffFull             => vc1RemBuffFull,
      vcWidth                   => "00",
      vcNum                     => "01"
   );


   -- VC2 Model
   U_Pgp2Vc2Test: Pgp2VcTest port map (
      pgpRxClk                  => pgpClk,
      pgpRxRst                  => pgpReset,
      pgpTxClk                  => pgpClk,
      pgpTxRst                  => pgpReset,
      pgpLinkReady              => pgpLinkReady,
      vcTxValid                 => vc2FrameTxValid,
      vcTxReady                 => vc2FrameTxReady,
      vcTxSOF                   => vc2FrameTxSOF,
      vcTxEOF                   => vc2FrameTxEOF,
      vcTxEOFE                  => vc2FrameTxEOFE,
      vcTxDataLow(15 downto  0) => vc2FrameTxData,
      vcTxDataLow(31 downto 16) => open,
      vcTxDataHigh              => open,
      vcLocBuffAFull            => vc2LocBuffAFull,
      vcLocBuffFull             => vc2LocBuffFull,
      vcRxSOF                   => vcFrameRxSOF,
      vcRxEOF                   => vcFrameRxEOF,
      vcRxEOFE                  => vcFrameRxEOFE,
      vcRxDataLow(15 downto  0) => vcFrameRxData,
      vcRxDataLow(31 downto 16) => (others=>'0'),
      vcRxDataHigh              => (others=>'0'),
      vcRxValid                 => vc2FrameRxValid,
      vcRemBuffAFull            => vc2RemBuffAFull,
      vcRemBuffFull             => vc2RemBuffFull,
      vcWidth                   => "00",
      vcNum                     => "10"
   );


   -- VC3 Model
   U_Pgp2Vc3Test: Pgp2VcTest port map (
      pgpRxClk                  => pgpClk,
      pgpRxRst                  => pgpReset,
      pgpTxClk                  => pgpClk,
      pgpTxRst                  => pgpReset,
      pgpLinkReady              => pgpLinkReady,
      vcTxValid                 => vc3FrameTxValid,
      vcTxReady                 => vc3FrameTxReady,
      vcTxSOF                   => vc3FrameTxSOF,
      vcTxEOF                   => vc3FrameTxEOF,
      vcTxEOFE                  => vc3FrameTxEOFE,
      vcTxDataLow(15 downto  0) => vc3FrameTxData,
      vcTxDataLow(31 downto 16) => open,
      vcTxDataHigh              => open,
      vcLocBuffAFull            => vc3LocBuffAFull,
      vcLocBuffFull             => vc3LocBuffFull,
      vcRxSOF                   => vcFrameRxSOF,
      vcRxEOF                   => vcFrameRxEOF,
      vcRxEOFE                  => vcFrameRxEOFE,
      vcRxDataLow(15 downto  0) => vcFrameRxData,
      vcRxDataLow(31 downto 16) => (others=>'0'),
      vcRxDataHigh              => (others=>'0'),
      vcRxValid                 => vc3FrameRxValid,
      vcRemBuffAFull            => vc3RemBuffAFull,
      vcRemBuffFull             => vc3RemBuffFull,
      vcWidth                   => "00",
      vcNum                     => "11"
   );

end Pgp2Gtp16Tb;

