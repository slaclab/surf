-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, GTX Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2Gtx16.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 08/18/2009
-------------------------------------------------------------------------------
-- Description:
-- VHDL source file containing the PGP, GTX and CRC blocks.
-- This module also contains the logic to control the reset of the GTX.
-------------------------------------------------------------------------------
-- Copyright (c) 2006 by Ryan Herbst. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 08/18/2009: created.
-- 01/13/2010: Added received init line to help linking.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.Pgp2GtxPackage.all;
use work.Pgp2CorePackage.all;
use work.Pgp2CoreTypesPkg.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;


entity Pgp2Gtx16LowLat is
  generic (
    TPD_G        : time    := 1 ns;
    EnShortCells : integer := 1;        -- Enable short non-EOF cells
    VcInterleave : integer := 1         -- Interleave Frames
    );
  port (

    -- System clock, reset & control
    pgpReset   : in std_logic;          -- Synchronous reset input
    pgpTxClk   : in std_logic;          -- 125 MHz Tx clock (PgpTx)

    pgpRxRecClk    : out std_logic;     -- rxrecclk basically
    pgpRxRecClkRst : out std_logic;     -- Reset for recovered clock

    -- Non VC Rx Signals
    pgpRxIn  : in  PgpRxInType;
    pgpRxOut : out PgpRxOutType;

    -- Non VC Tx Signals
    pgpTxIn  : in  PgpTxInType;
    pgpTxOut : out PgpTxOutType;

    -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
    pgpTxVcQuadIn  : in  PgpTxVcQuadInType;
    pgpTxVcQuadOut : out PgpTxVcQuadOutType;

    -- Frame Receive Interface - 1 Lane, Array of 4 VCs
    pgpRxVcCommonOut : out PgpRxVcCommonOutType;
    pgpRxVcQuadOut   : out PgpRxVcQuadOutType;

    -- GTX loopback control
    gtxLoopback : in std_logic;         -- GTX Serial Loopback Control

    -- GTX Signals
    gtxClkIn     : in  std_logic;       -- GTX Reference Clock In
    gtxRefClkOut : out std_logic;       -- GTX Reference Clock Output
    gtxRxN       : in  std_logic;       -- GTX Serial Receive Negative
    gtxRxP       : in  std_logic;       -- GTX Serial Receive Positive
    gtxTxN       : out std_logic;       -- GTX Serial Transmit Negative
    gtxTxP       : out std_logic;       -- GTX Serial Transmit Positive

    -- Debug
    debug : out std_logic_vector(63 downto 0)
    );

end Pgp2Gtx16LowLat;


-- Define architecture
architecture rtl of Pgp2Gtx16LowLat is

  --------------------------------------------------------------------------------------------------
  -- Shared GTX Signals
  --------------------------------------------------------------------------------------------------
  signal gtxPllLockDet : std_logic;     -- GTX PLLLKDET
  signal gtxReset      : std_logic;     -- GTXRESET
  signal gtxResetDone  : std_logic;     -- RESETDONE0

  --------------------------------------------------------------------------------------------------
  -- Rx Signals
  --------------------------------------------------------------------------------------------------
  -- Rx Clocks
  signal gtxRxUsrClk    : std_logic;    -- Recovered 2 byte clock
  signal gtxRxUsrClkRst : std_logic;

  -- Rx Resets
  signal gtxRxElecIdle    : std_logic;
  signal gtxRxReset       : std_logic;
  signal gtxRxCdrReset    : std_logic;


  -- PgpRx Signals
  signal phyRxLanesIn  : PgpRxPhyLaneInArray(0 to 0);   -- Output from decoder
  signal phyRxLanesOut : PgpRxPhyLaneOutArray(0 to 0);  -- Polarity to GTX
  signal phyRxReady    : std_logic;                     -- To RxRst
  signal phyRxInit     : std_logic;                     -- To RxRst
  signal crcRxIn       : PgpCrcInType;
  signal crcRxOut      : std_logic_vector(31 downto 0);

  -- CRC Rx IO (PgpRxPhy CRC IO must be adapted to V5 GTX CRCs)
  signal crcRxWidthGtx : std_logic_vector(2 downto 0);
  signal crcRxRstGtx   : std_logic;
  signal crcRxInGtx    : std_logic_vector(31 downto 0);
  signal crcRxOutGtx   : std_logic_vector(31 downto 0);

  --------------------------------------------------------------------------------------------------
  -- Tx Signals
  --------------------------------------------------------------------------------------------------
  -- PgpTx Signals
  signal phyTxLanesOut : PgpTxPhyLaneOutArray(0 to 0);
  signal phyTxReady    : std_logic;
  signal crcTxIn       : PgpCrcInType;
  signal crcTxOut      : std_logic_vector(31 downto 0);

  -- CRC Tx IO (PgpTxPhy CRC IO must be adapted to V5 GTX CRCs)
  signal crcTxWidthGtx : std_logic_vector(2 downto 0);
  signal crcTxRstGtx   : std_logic;
  signal crcTxInGtx    : std_logic_vector(31 downto 0);
  signal crcTxOutGtx   : std_logic_vector(31 downto 0);

  -- Reset signals
  signal gtxTxReset : std_logic;

begin

  --------------------------------------------------------------------------------------------------
  -- Misc
  --------------------------------------------------------------------------------------------------
  gtxReset <= pgpReset;

  --------------------------------------------------------------------------------------------------
  -- Rx Data Path
  --------------------------------------------------------------------------------------------------
  -- RX Reset Control
  -- Uses pgpTxClk! Needs free-running clock to work
  -- All outputs used asynchronously so this is ok
  U_Pgp2GtxRxRst : Pgp2GtxRxRst
    port map (
      gtxRxClk         => pgpTxClk,     -- Need free-running clock here so use TxClk
      gtxRxRst         => pgpReset,
      gtxRxReady       => open,
      gtxRxInit        => phyRxInit,
      gtxLockDetect    => gtxPllLockDet,
      gtxRxElecIdle    => gtxRxElecIdle,
      gtxRxBuffStatus  => "000",
      gtxRstDone       => gtxResetDone,
      gtxRxReset       => gtxRxReset,
      gtxRxCdrReset    => gtxRxCdrReset
      );

  -- Output recovered clocks for external use
  pgpRxRecClk    <= gtxRxUsrClk;
  pgpRxRecClkRst <= gtxRxUsrClkRst;

  -- PGP RX Block
  Pgp2RxWrapper_1 : entity work.Pgp2RxWrapper
    generic map (
      RxLaneCnt    => 1,
      EnShortCells => EnShortCells)
    port map (
      pgpRxClk         => gtxRxUsrClk,
      pgpRxReset       => pgpReset,
      pgpRxIn          => pgpRxIn,
      pgpRxOut         => pgpRxOut,
      pgpRxVcCommonOut => pgpRxVcCommonOut,
      pgpRxVcQuadOut   => pgpRxVcQuadOut,
      phyRxLanesOut    => phyRxLanesOut,
      phyRxLanesIn     => phyRxLanesIn,
      phyRxReady       => phyRxReady,   -- gtxRxAligned
      phyRxInit        => phyRxInit,
      crcRxIn          => crcRxIn,
      crcRxOut         => crcRxOut,
      debug            => open);

  -- RX CRC BLock
  -- Must adapt generic CRC type to GTX CRC block
  crcRxWidthGtx            <= "001";
  crcRxRstGtx              <= pgpReset or crcRxIn.init or gtxRxUsrClkRst;
  crcRxInGtx(31 downto 24) <= crcRxIn.crcIn(7 downto 0);
  crcRxInGtx(23 downto 16) <= crcRxIn.crcIn(15 downto 8);
  crcRxInGtx(15 downto 0)  <= (others => '0');
  crcRxOut                 <= not crcRxOutGtx;  -- Invert Output CRC

  Rx_CRC : CRC32
    generic map(
      CRC_INIT => x"FFFFFFFF"
      ) port map(
        CRCOUT       => crcRxOutGtx,
        CRCCLK       => gtxRxUsrClk,
        CRCDATAVALID => crcRxIn.valid,
        CRCDATAWIDTH => crcRxWidthGtx,
        CRCIN        => crcRxInGtx,
        CRCRESET     => crcRxRstGtx
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
      pgpTxVcQuadIn  => pgpTxVcQuadIn,
      pgpTxVcQuadOut => pgpTxVcQuadOut,
      phyTxLanesOut  => phyTxLanesOut,
      phyTxReady     => phyTxReady,     -- Tx Aligned?
      crcTxIn        => crcTxIn,
      crcTxOut       => crcTxOut,
      debug          => open);


  -- Adapt CRC data width flag
  crcTxWidthGtx            <= "001";
  crcTxRstGtx              <= pgpReset or crcTxIn.init;
  -- Pass CRC data in on proper bits
  crcTxInGtx(31 downto 24) <= crcTxIn.crcIn(7 downto 0);
  crcTxInGtx(23 downto 16) <= crcTxIn.crcIn(15 downto 8);
  crcTxInGtx(15 downto 0)  <= (others => '0');
  crcTxOut                 <= not crcTxOutGtx;

  -- TX CRC BLock
  Tx_CRC : CRC32
    generic map(
      CRC_INIT => x"FFFFFFFF"
      )
    port map(
      CRCOUT       => crcTxOutGtx,
      CRCCLK       => pgpTxClk,
      CRCDATAVALID => crcTxIn.valid,
      CRCDATAWIDTH => crcTxWidthGtx,
      CRCIN        => crcTxInGtx,
      CRCRESET     => crcTxRstGtx
      );

  -- TX Reset Control
  U_Pgp2GtxTxRst : Pgp2GtxTxRst
    port map (
      gtxTxClk        => pgpTxClk,
      gtxTxRst        => pgpReset,
      gtxTxReady      => open,
      gtxLockDetect   => gtxPllLockDet,
      gtxTxBuffStatus => "00",
      gtxRstDone      => gtxResetDone,
      gtxTxReset      => gtxTxReset
      );


  --------------------------------------------------------------------------------------------------
  -- GTX Low Lat
  --------------------------------------------------------------------------------------------------
  Gtx16LowLatCore_1 : entity work.Gtx16LowLatCore
    generic map (
      TPD_G           => TPD_G,
      SIM_PLL_PERDIV2 => X"0C8", --"011001000",
      CLK25_DIVIDER   => 5,
      PLL_DIVSEL_FB   => 2,
      PLL_DIVSEL_REF  => 1,
      REC_CLK_PERIOD  => 8.000,
      REC_PLL_MULT    => 11,            -- 11 runs PLL at optimal VCO freq
      REC_PLL_DIV     => 1)
    port map (
      gtxClkIn         => gtxClkIn,
      gtxRefClkOut     => gtxRefClkOut,
      gtxRxN           => gtxRxN,
      gtxRxP           => gtxRxP,
      gtxTxN           => gtxTxN,
      gtxTxP           => gtxTxP,
      gtxReset         => gtxReset,
      gtxResetDone     => gtxResetDone,
      gtxPllLockDet    => gtxPllLockDet,
      gtxLoopback      => gtxLoopback,
      gtxRxReset       => gtxRxReset,
      gtxRxCdrReset    => gtxRxCdrReset,
      gtxRxElecIdle    => gtxRxElecIdle,
      gtxRxUsrClk      => gtxRxUsrClk,
      gtxRxUsrClkRst   => gtxRxUsrClkRst,
      gtxRxData        => phyRxLanesIn(0).data,
      gtxRxDataK       => phyRxLanesIn(0).dataK,
      gtxRxDecErr      => phyRxLanesIn(0).decErr,
      gtxRxDispErr     => phyRxLanesIn(0).dispErr,
      gtxRxPolarity    => phyRxLanesOut(0).polarity,
      gtxRxAligned     => phyRxReady,
      gtxTxReset       => gtxTxReset,
      gtxTxUsrClk      => pgpTxClk,
      gtxTxAligned     => phyTxReady,
      gtxTxData        => phyTxLanesOut(0).data,
      gtxTxDataK       => phyTxLanesOut(0).dataK);

end rtl;

