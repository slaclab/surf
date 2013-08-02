-------------------------------------------------------------------------------
-- Title         : Pretty Good Protocol, V2, GTP Wrapper
-- Project       : General Purpose Core
-------------------------------------------------------------------------------
-- File          : Pgp2GtpDual.vhd
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
use work.StdRtlPkg.all;
use work.VcPkg.all;
library UNISIM;
use UNISIM.VCOMPONENTS.all;


entity Pgp2GtpDualFixedLat is
   generic (
      TPD_G        : time    := 1 ns;
      EnShortCells : integer := 1;      -- Enable short non-EOF cells
      VcInterleave : integer := 1       -- Interleave Frames
      );
   port (

      -- System clock, reset & control
      pgpReset   : in sl;               -- Synchronous reset input
      pgpTxClk   : in sl;               -- 125 MHz Tx clock (PgpTx)
      pgpTxClk2x : in sl;               -- 250 MHz Tx clock (GTP)

      pgpRxRecClk    : out slv(1 downto 0);  -- rxrecclk basically
      pgpRxRecClk2x  : out slv(1 downto 0);  -- double byte clock
      pgpRxRecClkRst : out slv(1 downto 0);  -- Reset for recovered clock

      -- Non VC Rx Signals
      pgpRxIn  : in  PgpRxInArray(1 downto 0);
      pgpRxOut : out PgpRxOutArray(1 downto 0);

      -- Non VC Tx Signals
      pgpTxIn  : in  PgpTxInArray(1 downto 0);
      pgpTxOut : out PgpTxOutArray(1 downto 0);

      -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
      pgpVcTxQuadIn  : in  VcTxQuadInArray(1 downto 0);
      pgpVcTxQuadOut : out VcTxQuadOutArray(1 downto 0);

      -- Frame Receive Interface - 1 Lane, Array of 4 VCs
      pgpVcRxCommonOut : out VcRxCommonOutArray(1 downto 0);
      pgpVcRxQuadOut   : out VcRxQuadOutArray(1 downto 0);

      -- GTP loopback control
      gtpLoopback : in slv(1 downto 0);  -- GTP Serial Loopback Control

      -- GTP Signals
      gtpClkIn     : in  sl;               -- GTP Reference Clock In
      gtpRefClkOut : out sl;               -- GTP Reference Clock Output
      gtpRxN       : in  slv(1 downto 0);  -- GTP Serial Receive Negative
      gtpRxP       : in  slv(1 downto 0);  -- GTP Serial Receive Positive
      gtpTxN       : out slv(1 downto 0);  -- GTP Serial Transmit Negative
      gtpTxP       : out slv(1 downto 0);  -- GTP Serial Transmit Positive

      -- Debug
      debug : out slv(63 downto 0)
      );

end Pgp2GtpDualFixedLat;


-- Define architecture
architecture rtl of Pgp2GtpDualFixedLat is

   -- Yes, I know this is silly, but VHDL makes it necessary.
   type PgpRxPhy1LaneOutArray is array (natural range <>) of PgpRxPhyLaneOutArray(0 downto 0);
   type PgpRxPhy1LaneInArray is array (natural range <>) of PgpRxPhyLaneInArray(0 downto 0);
   type PgpTxPhy1LaneOutArray is array (natural range <>) of PgpTxPhyLaneOutArray(0 downto 0);

   --------------------------------------------------------------------------------------------------
   -- Shared GTP Signals
   --------------------------------------------------------------------------------------------------
   signal gtpPllLockDet : sl;               -- GTP PLLLKDET
   signal gtpReset      : sl;               -- GTPRESET
   signal gtpResetDone  : slv(1 downto 0);  -- RESETDONE0

   --------------------------------------------------------------------------------------------------
   -- Rx Signals
   --------------------------------------------------------------------------------------------------
   -- Rx Clocks
   signal gtpRxUsrClk    : slv(1 downto 0);  -- Recovered 1 byte clock
   signal gtpRxUsrClk2   : slv(1 downto 0);  -- Recovered 2 byte clock
   signal gtpRxUsrClkRst : slv(1 downto 0);

   -- Rx Resets
   signal gtpRxElecIdle    : slv(1 downto 0);
   signal gtpRxElecIdleRst : slv(1 downto 0);
   signal gtpRxReset       : slv(1 downto 0);
   signal gtpRxCdrReset    : slv(1 downto 0);

   -- PgpRx Signals
   signal phyRxLanesIn  : PgpRxPhy1LaneInArray(1 downto 0);   -- Output from decoder
   signal phyRxLanesOut : PgpRxPhy1LaneOutArray(1 downto 0);  -- Polarity to GTP
   signal phyRxReady    : slv(1 downto 0);                    -- To RxRst
   signal phyRxInit     : slv(1 downto 0);                    -- To RxRst
   signal crcRxIn       : PgpCrcInArray(1 downto 0);
   signal crcRxOut      : slv32Array(1 downto 0);

   -- CRC Rx IO (PgpRxPhy CRC IO must be adapted to V5 GTP CRCs)
   signal crcRxWidthGtp : slv3Array(1 downto 0);
   signal crcRxRstGtp   : slv(1 downto 0);
   signal crcRxInGtp    : slv32Array(1 downto 0);
   signal crcRxOutGtp   : slv32Array(1 downto 0);

   --------------------------------------------------------------------------------------------------
   -- Tx Signals
   --------------------------------------------------------------------------------------------------
   -- PgpTx Signals
   signal phyTxLanesOut : PgpTxPhy1LaneOutArray(1 downto 0);
   signal phyTxReady    : sl;
   signal crcTxIn       : PgpCrcInArray(1 downto 0);
   signal crcTxOut      : slv32Array(1 downto 0);

   -- CRC Tx IO (PgpTxPhy CRC IO must be adapted to V5 GTP CRCs)
   signal crcTxWidthGtp : slv3Array(1 downto 0);
   signal crcTxRstGtp   : slv(1 downto 0);
   signal crcTxInGtp    : slv32Array(1 downto 0);
   signal crcTxOutGtp   : slv32Array(1 downto 0);

   -- Reset signals
   signal gtpTxReset : slv(1 downto 0);

begin

   --------------------------------------------------------------------------------------------------
   -- Misc
   --------------------------------------------------------------------------------------------------
   gtpReset <= pgpReset;

   DUAL_INST_LOOP : for i in 1 downto 0 generate

      --------------------------------------------------------------------------------------------------
      -- Rx Data Path
      --------------------------------------------------------------------------------------------------
      -- RX Reset Control
      -- Uses pgpTxClk! Needs free-running clock to work
      -- All outputs used asynchronously so this is ok
      U_Pgp2GtpRxRst : Pgp2GtpRxRst
         port map (
            gtpRxClk         => pgpTxClk,  -- Need free-running clock here so use TxClk
            gtpRxRst         => pgpReset,
            gtpRxReady       => open,
            gtpRxInit        => phyRxInit(i),
            gtpLockDetect    => gtpPllLockDet,
            gtpRxElecIdle    => gtpRxElecIdle(i),
            gtpRxBuffStatus  => "000",
            gtpRstDone       => gtpResetDone(i),
            gtpRxElecIdleRst => gtpRxElecIdleRst(i),
            gtpRxReset       => gtpRxReset(i),
            gtpRxCdrReset    => gtpRxCdrReset(i)
            );

      -- Output recovered clocks for external use
      pgpRxRecClk(i)    <= gtpRxUsrClk2(i);
      pgpRxRecClk2x(i)  <= gtpRxUsrClk(i);
      pgpRxRecClkRst(i) <= gtpRxUsrClkRst(i);

      -- PGP RX Block
      Pgp2RxWrapper_1 : entity work.Pgp2RxWrapper
         generic map (
            RxLaneCnt    => 1,
            EnShortCells => EnShortCells)
         port map (
            pgpRxClk         => gtpRxUsrClk2(i),
            pgpRxReset       => pgpReset,
            pgpRxIn          => pgpRxIn(i),
            pgpRxOut         => pgpRxOut(i),
            pgpVcRxCommonOut => pgpVcRxCommonOut(i),
            pgpVcRxQuadOut   => pgpVcRxQuadOut(i),
            phyRxLanesOut    => phyRxLanesOut(i),
            phyRxLanesIn     => phyRxLanesIn(i),
            phyRxReady       => phyRxReady(i),  -- gtpRxAligned
            phyRxInit        => phyRxInit(i),
            crcRxIn          => crcRxIn(i),
            crcRxOut         => crcRxOut(i),
            debug            => open);

      -- RX CRC BLock
      -- Must adapt generic CRC type to GTP CRC block
      crcRxWidthGtp(i)            <= "001";
      crcRxRstGtp(i)              <= pgpReset or crcRxIn(i).init or gtpRxUsrClkRst(i);
      crcRxInGtp(i)(31 downto 24) <= crcRxIn(i).crcIn(7 downto 0);
      crcRxInGtp(i)(23 downto 16) <= crcRxIn(i).crcIn(15 downto 8);
      crcRxInGtp(i)(15 downto 0)  <= (others => '0');
      crcRxOut(i)                 <= not crcRxOutGtp(i);  -- Invert Output CRC

      Rx_CRC : CRC32
         generic map(
            CRC_INIT => x"FFFFFFFF"
            ) port map(
               CRCOUT       => crcRxOutGtp(i),
               CRCCLK       => gtpRxUsrClk2(i),
               CRCDATAVALID => crcRxIn(i).valid,
               CRCDATAWIDTH => crcRxWidthGtp(i),
               CRCIN        => crcRxInGtp(i),
               CRCRESET     => crcRxRstGtp(i)
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
            pgpTxIn        => pgpTxIn(i),
            pgpTxOut       => pgpTxOut(i),
            pgpVcTxQuadIn  => pgpVcTxQuadIn(i),
            pgpVcTxQuadOut => pgpVcTxQuadOut(i),
            phyTxLanesOut  => phyTxLanesOut(i),
            phyTxReady     => phyTxReady,
            crcTxIn        => crcTxIn(i),
            crcTxOut       => crcTxOut(i),
            debug          => open);


      -- Adapt CRC data width flag
      crcTxWidthGtp(i)            <= "001";
      crcTxRstGtp(i)              <= pgpReset or crcTxIn(i).init;
      -- Pass CRC data in on proper bits
      crcTxInGtp(i)(31 downto 24) <= crcTxIn(i).crcIn(7 downto 0);
      crcTxInGtp(i)(23 downto 16) <= crcTxIn(i).crcIn(15 downto 8);
      crcTxInGtp(i)(15 downto 0)  <= (others => '0');
      crcTxOut(i)                 <= not crcTxOutGtp(i);

      -- TX CRC BLock
      Tx_CRC : CRC32
         generic map(
            CRC_INIT => x"FFFFFFFF"
            )
         port map(
            CRCOUT       => crcTxOutGtp(i),
            CRCCLK       => pgpTxClk,
            CRCDATAVALID => crcTxIn(i).valid,
            CRCDATAWIDTH => crcTxWidthGtp(i),
            CRCIN        => crcTxInGtp(i),
            CRCRESET     => crcTxRstGtp(i)
            );

      -- TX Reset Control
      U_Pgp2GtpTxRst : Pgp2GtpTxRst
         port map (
            gtpTxClk        => pgpTxClk,
            gtpTxRst        => pgpReset,
            gtpTxReady      => open,
            gtpLockDetect   => gtpPllLockDet,
            gtpTxBuffStatus => "00",
            gtpRstDone      => gtpResetDone(i),
            gtpTxReset      => gtpTxReset(i)
            );

   end generate DUAL_INST_LOOP;
   --------------------------------------------------------------------------------------------------
   -- GTP Low Lat
   --------------------------------------------------------------------------------------------------
   GtpDualFixedLatCore_1 : entity work.GtpDualFixedLatCore
      generic map (
         TPD_G           => TPD_G,
         SIM_PLL_PERDIV2 => X"0C8",
         CLK25_DIVIDER   => 5,
         PLL_DIVSEL_FB   => 2,
         PLL_DIVSEL_REF  => 1,
         REC_CLK_PERIOD  => 4.000,
         REC_PLL_MULT    => 4,          -- 4 runs PLL at optimal VCO freq
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
         gtpRxData(0)     => phyRxLanesIn(0)(0).data,
         gtpRxData(1)     => phyRxLanesIn(1)(0).data,
         gtpRxDataK(0)    => phyRxLanesIn(0)(0).dataK,
         gtpRxDataK(1)    => phyRxLanesIn(1)(0).dataK,
         gtpRxDecErr(0)   => phyRxLanesIn(0)(0).decErr,
         gtpRxDecErr(1)   => phyRxLanesIn(1)(0).decErr,
         gtpRxDispErr(0)  => phyRxLanesIn(0)(0).dispErr,
         gtpRxDispErr(1)  => phyRxLanesIn(1)(0).dispErr,
         gtpRxPolarity(0) => phyRxLanesOut(0)(0).polarity,
         gtpRxPolarity(1) => phyRxLanesOut(1)(0).polarity,
         gtpRxAligned     => phyRxReady,
         gtpTxReset       => gtpTxReset,
         gtpTxUsrClk      => pgpTxClk2x,
         gtpTxUsrClk2     => pgpTxClk,
         gtpTxAligned     => phyTxReady,
         gtpTxData(0)     => phyTxLanesOut(0)(0).data,
         gtpTxData(1)     => phyTxLanesOut(1)(0).data,
         gtpTxDataK(0)    => phyTxLanesOut(0)(0).dataK,
         gtpTxDataK(1)    => phyTxLanesOut(1)(0).dataK);

end rtl;

