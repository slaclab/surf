-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, GTP Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Gtp16.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 08/18/2009
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file containing the PGP, GTP and CRC blocks.
-- This module also contains the logic to control the reset of the GTP.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 08/18/2009: created.
-- 01/13/2010: Added received init line to help linking.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.Pgp2GtpPackage.all;
use work.Pgp2CorePackage.all;
use work.Pgp2CoreTypesPkg.all;
use work.VcPkg.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;


entity Pgp2Gtp16FixedLat is
  generic (
    TPD_G        : time    := 1 ns;
    EnShortCells : integer := 1;        -- Enable short non-EOF cells
    VcInterleave : integer := 1         -- Interleave Frames
    );
  port (

    -- System clock, reset & control
    pgpReset   : in std_logic;          -- Synchronous reset input
    pgpTxClk   : in std_logic;          -- 125 MHz Tx clock (PgpTx)
    pgpTxClk2x : in std_logic;          -- 250 MHz Tx clock (GTP)

    pgpRxRecClk    : out std_logic;     -- rxrecclk basically
    pgpRxRecClk2x  : out std_logic;     -- double byte clock
    pgpRxRecClkRst : out std_logic;     -- Reset for recovered clock

    -- Non VC Rx Signals
    pgpRxIn  : in  PgpRxInType;
    pgpRxOut : out PgpRxOutType;

    -- Non VC Tx Signals
    pgpTxIn  : in  PgpTxInType;
    pgpTxOut : out PgpTxOutType;

    -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
    pgpVcTxQuadIn  : in  VcTxQuadInType;
    pgpVcTxQuadOut : out VcTxQuadOutType;

    -- Frame Receive Interface - 1 Lane, Array of 4 VCs
    pgpVcRxCommonOut : out VcRxCommonOutType;
    pgpVcRxQuadOut   : out VcRxQuadOutType;

    -- GTP loopback control
    gtpLoopback : in std_logic;         -- GTP Serial Loopback Control

    -- GTP Signals
    gtpClkIn     : in  std_logic;       -- GTP Reference Clock In
    gtpRefClkOut : out std_logic;       -- GTP Reference Clock Output
    gtpRxN       : in  std_logic;       -- GTP Serial Receive Negative
    gtpRxP       : in  std_logic;       -- GTP Serial Receive Positive
    gtpTxN       : out std_logic;       -- GTP Serial Transmit Negative
    gtpTxP       : out std_logic;       -- GTP Serial Transmit Positive

    -- Debug
    debug : out std_logic_vector(63 downto 0)
    );

end Pgp2Gtp16FixedLat;


-- Define architecture
architecture rtl of Pgp2Gtp16FixedLat is

  --------------------------------------------------------------------------------------------------
  -- Shared GTP Signals
  --------------------------------------------------------------------------------------------------
  signal gtpPllLockDet : std_logic;     -- GTP PLLLKDET
  signal gtpReset      : std_logic;     -- GTPRESET
  signal gtpResetDone  : std_logic;     -- RESETDONE0

  --------------------------------------------------------------------------------------------------
  -- Rx Signals
  --------------------------------------------------------------------------------------------------
  -- Rx Clocks
  signal gtpRxUsrClk    : std_logic;    -- Recovered 1 byte clock
  signal gtpRxUsrClk2   : std_logic;    -- Recovered 2 byte clock
  signal gtpRxUsrClkRst : std_logic;

  -- Rx Resets
  signal gtpRxElecIdle    : std_logic;
  signal gtpRxElecIdleRst : std_logic;
  signal gtpRxReset       : std_logic;
  signal gtpRxCdrReset    : std_logic;

  -- PgpRx Signals
  signal phyRxLanesIn  : PgpRxPhyLaneInArray(0 to 0);   -- Output from decoder
  signal phyRxLanesOut : PgpRxPhyLaneOutArray(0 to 0);  -- Polarity to GTP
  signal phyRxReady    : std_logic;                     -- To RxRst
  signal phyRxInit     : std_logic;                     -- To RxRst
  signal crcRxIn       : PgpCrcInType;
  signal crcRxOut      : std_logic_vector(31 downto 0);

  -- CRC Rx IO (PgpRxPhy CRC IO must be adapted to V5 GTP CRCs)
  signal crcRxWidthGtp : std_logic_vector(2 downto 0);
  signal crcRxRstGtp   : std_logic;
  signal crcRxInGtp    : std_logic_vector(31 downto 0);
  signal crcRxOutGtp   : std_logic_vector(31 downto 0);

  --------------------------------------------------------------------------------------------------
  -- Tx Signals
  --------------------------------------------------------------------------------------------------
  -- PgpTx Signals
  signal phyTxLanesOut : PgpTxPhyLaneOutArray(0 to 0);
  signal phyTxReady    : std_logic;
  signal crcTxIn       : PgpCrcInType;
  signal crcTxOut      : std_logic_vector(31 downto 0);

  -- CRC Tx IO (PgpTxPhy CRC IO must be adapted to V5 GTP CRCs)
  signal crcTxWidthGtp : std_logic_vector(2 downto 0);
  signal crcTxRstGtp   : std_logic;
  signal crcTxInGtp    : std_logic_vector(31 downto 0);
  signal crcTxOutGtp   : std_logic_vector(31 downto 0);

  -- Reset signals
  signal gtpTxReset : std_logic;

begin

  --------------------------------------------------------------------------------------------------
  -- Misc
  --------------------------------------------------------------------------------------------------
  gtpReset <= pgpReset;

  --------------------------------------------------------------------------------------------------
  -- Rx Data Path
  --------------------------------------------------------------------------------------------------
  -- RX Reset Control
  -- Uses pgpTxClk! Needs free-running clock to work
  -- All outputs used asynchronously so this is ok
  U_Pgp2GtpRxRst : Pgp2GtpRxRst
    port map (
      gtpRxClk         => pgpTxClk,     -- Need free-running clock here so use TxClk
      gtpRxRst         => pgpReset,
      gtpRxReady       => open,
      gtpRxInit        => phyRxInit,
      gtpLockDetect    => gtpPllLockDet,
      gtpRxElecIdle    => gtpRxElecIdle,
      gtpRxBuffStatus  => "000",
      gtpRstDone       => gtpResetDone,
      gtpRxElecIdleRst => gtpRxElecIdleRst,
      gtpRxReset       => gtpRxReset,
      gtpRxCdrReset    => gtpRxCdrReset
      );

  -- Output recovered clocks for external use
  pgpRxRecClk    <= gtpRxUsrClk2;
  pgpRxRecClk2x  <= gtpRxUsrClk;
  pgpRxRecClkRst <= gtpRxUsrClkRst;

  -- PGP RX Block
  Pgp2RxWrapper_1 : entity work.Pgp2RxWrapper
    generic map (
      RxLaneCnt    => 1,
      EnShortCells => EnShortCells)
    port map (
      pgpRxClk         => gtpRxUsrClk2,
      pgpRxReset       => pgpReset,
      pgpRxIn          => pgpRxIn,
      pgpRxOut         => pgpRxOut,
      pgpVcRxCommonOut => pgpVcRxCommonOut,
      pgpVcRxQuadOut   => pgpVcRxQuadOut,
      phyRxLanesOut    => phyRxLanesOut,
      phyRxLanesIn     => phyRxLanesIn,
      phyRxReady       => phyRxReady,   -- gtpRxAligned
      phyRxInit        => phyRxInit,
      crcRxIn          => crcRxIn,
      crcRxOut         => crcRxOut,
      debug            => open);

  -- RX CRC BLock
  -- Must adapt generic CRC type to GTP CRC block
  crcRxWidthGtp            <= "001";
  crcRxRstGtp              <= pgpReset or crcRxIn.init or gtpRxUsrClkRst;
  crcRxInGtp(31 downto 24) <= crcRxIn.crcIn(7 downto 0);
  crcRxInGtp(23 downto 16) <= crcRxIn.crcIn(15 downto 8);
  crcRxInGtp(15 downto 0)  <= (others => '0');
  crcRxOut                 <= not crcRxOutGtp;  -- Invert Output CRC

  Rx_CRC : CRC32
    generic map(
      CRC_INIT => x"FFFFFFFF"
      ) port map(
        CRCOUT       => crcRxOutGtp,
        CRCCLK       => gtpRxUsrClk2,
        CRCDATAVALID => crcRxIn.valid,
        CRCDATAWIDTH => crcRxWidthGtp,
        CRCIN        => crcRxInGtp,
        CRCRESET     => crcRxRstGtp
        );


  --------------------------------------------------------------------------------------------------
  -- Tx Data Path
  --------------------------------------------------------------------------------------------------

  Pgp2TxWrapper_1 : entity work.Pgp2TxWrapper
    generic map (
      TxLaneCnt    => 1,
      VcInterleave => VcInterleave)
    port map (
      pgpTxClk       => pgpTxClk,
      pgpTxReset     => pgpReset,
      pgpTxIn        => pgpTxIn,
      pgpTxOut       => pgpTxOut,
      pgpVcTxQuadIn  => pgpVcTxQuadIn,
      pgpVcTxQuadOut => pgpVcTxQuadOut,
      phyTxLanesOut  => phyTxLanesOut,
      phyTxReady     => phyTxReady,     -- Tx Aligned?
      crcTxIn        => crcTxIn,
      crcTxOut       => crcTxOut,
      debug          => open);


  -- Adapt CRC data width flag
  crcTxWidthGtp            <= "001";
  crcTxRstGtp              <= pgpReset or crcTxIn.init;
  -- Pass CRC data in on proper bits
  crcTxInGtp(31 downto 24) <= crcTxIn.crcIn(7 downto 0);
  crcTxInGtp(23 downto 16) <= crcTxIn.crcIn(15 downto 8);
  crcTxInGtp(15 downto 0)  <= (others => '0');
  crcTxOut                 <= not crcTxOutGtp;

  -- TX CRC BLock
  Tx_CRC : CRC32
    generic map(
      CRC_INIT => x"FFFFFFFF"
      )
    port map(
      CRCOUT       => crcTxOutGtp,
      CRCCLK       => pgpTxClk,
      CRCDATAVALID => crcTxIn.valid,
      CRCDATAWIDTH => crcTxWidthGtp,
      CRCIN        => crcTxInGtp,
      CRCRESET     => crcTxRstGtp
      );

  -- TX Reset Control
  U_Pgp2GtpTxRst : Pgp2GtpTxRst
    port map (
      gtpTxClk        => pgpTxClk,
      gtpTxRst        => pgpReset,
      gtpTxReady      => open,
      gtpLockDetect   => gtpPllLockDet,
      gtpTxBuffStatus => "00",
      gtpRstDone      => gtpResetDone,
      gtpTxReset      => gtpTxReset
      );


  --------------------------------------------------------------------------------------------------
  -- GTP Low Lat
  --------------------------------------------------------------------------------------------------
  Gtp16FixedLatCore_1 : entity work.Gtp16FixedLatCore
    generic map (
      TPD_G           => TPD_G,
      SIM_PLL_PERDIV2 => X"0C8",
      CLK25_DIVIDER   => 5,
      PLL_DIVSEL_FB   => 2,
      PLL_DIVSEL_REF  => 1,
      REC_CLK_PERIOD  => 4.000,
      REC_PLL_MULT    => 4,             -- 4 runs PLL at optimal VCO freq
      REC_PLL_DIV     => 1)
    port map (
      gtpClkIn         => gtpClkIn,
      gtpRefClkOut     => gtpRefClkOut,
      gtpRxN           => gtpRxN,
      gtpRxP           => gtpRxP,
      gtpTxN           => gtpTxN,
      gtpTxP           => gtpTxP,
      gtpReset         => gtpReset,
      gtpResetDone     => gtpResetDone,
      gtpPllLockDet    => gtpPllLockDet,
      gtpLoopback      => gtpLoopback,
      gtpRxReset       => gtpRxReset,
      gtpRxCdrReset    => gtpRxCdrReset,
      gtpRxElecIdle    => gtpRxElecIdle,
      gtpRxElecIdleRst => gtpRxElecIdleRst,
      gtpRxUsrClk      => gtpRxUsrClk,
      gtpRxUsrClk2     => gtpRxUsrClk2,
      gtpRxUsrClkRst   => gtpRxUsrClkRst,
      gtpRxData        => phyRxLanesIn(0).data,
      gtpRxDataK       => phyRxLanesIn(0).dataK,
      gtpRxDecErr      => phyRxLanesIn(0).decErr,
      gtpRxDispErr     => phyRxLanesIn(0).dispErr,
      gtpRxPolarity    => phyRxLanesOut(0).polarity,
      gtpRxAligned     => phyRxReady,
      gtpTxReset       => gtpTxReset,
      gtpTxUsrClk      => pgpTxClk2x,
      gtpTxUsrClk2     => pgpTxClk,
      gtpTxAligned     => phyTxReady,
      gtpTxData        => phyTxLanesOut(0).data,
      gtpTxDataK       => phyTxLanesOut(0).dataK);

end rtl;

