-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2Gtx7Fixedlat.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2014-06-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gtx7 Wrapper
--
-- Dependencies:  ^/pgp2_core/trunk/rtl/core/Pgp2RxWrapper.vhd
--                ^/pgp2_core/trunk/rtl/core/Pgp2TxWrapper.vhd
--                ^/StdLib/trunk/rtl/CRC32Rtl.vhd
--                ^/MgtLib/trunk/rtl/gtx7/Gtx7Core.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.Pgp2CoreTypesPkg.all;
use work.StdRtlPkg.all;
use work.VcPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp2Gtx7Fixedlat is
   generic (
      TPD_G : time := 1 ns;

      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics --
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "4.0";
      SIMULATION_G          : boolean    := false;
      STABLE_CLOCK_PERIOD_G : real       := 8.0E-9;  --units of seconds
      -- CPLL Settings - Defaults to 2.5 Gbps operation 
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      CPLL_FBDIV_G          : integer    := 4;
      CPLL_FBDIV_45_G       : integer    := 5;
      CPLL_REFCLK_DIV_G     : integer    := 1;
      RXOUT_DIV_G           : integer    := 2;
      TXOUT_DIV_G           : integer    := 2;
      RX_CLK25_DIV_G        : integer    := 5;
      TX_CLK25_DIV_G        : integer    := 5;

      RX_OS_CFG_G  : bit_vector := "0000010000000";        -- Set by wizard
      RXCDR_CFG_G  : bit_vector := x"03000023ff40200020";  -- Set by wizard
      RXDFEXYDEN_G : sl         := '0';                    -- Set by wizard

      -- RX Equalizer Attributes
      RX_DFE_KL_CFG2_G : bit_vector := x"3008E56A";  -- Set by wizard
      -- Configure PLL sources
      TX_PLL_G         : string     := "QPLL";
      RX_PLL_G         : string     := "CPLL";

      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      EnShortCells : integer              := 1;  -- Enable short non-EOF cells
      VcInterleave : integer              := 1;  -- Interleave Frames
      NUM_VC_EN_G  : integer range 1 to 4 := 4);
   port (
      -- GT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      gtCPllRefClk     : in  sl := '0';          -- Drives CPLL if used
      gtCPllLock       : out sl;
      gtQPllRefClk     : in  sl := '0';          -- Signals from QPLL if used
      gtQPllClk        : in  sl := '0';
      gtQPllLock       : in  sl := '0';
      gtQPllRefClkLost : in  sl := '0';
      gtQPllReset      : out sl;
      gtRxRefClkBufg   : in sl;         -- gtrefclk driving rx side, fed through clock buffer

      -- Gt Serial IO
      gtRxN : in  sl;                   -- GT Serial Receive Negative
      gtRxP : in  sl;                   -- GT Serial Receive Positive
      gtTxN : out sl;                   -- GT Serial Transmit Negative
      gtTxP : out sl;                   -- GT Serial Transmit Positive

      -- Tx Clocking
      pgpTxReset : in sl;
      pgpTxClk   : in sl;               -- ????

      -- Rx clocking
      pgpRxReset      : in  sl;
      pgpRxRecClk     : out sl;         -- rxrecclk basically
      pgpRxRecClkRst  : out sl;         -- Reset for recovered clock
      pgpRxClk        : in  sl;  -- Run recClk through external MMCM and sent to this input
      pgpRxMmcmReset  : out sl;
      pgpRxMmcmLocked : in  sl := '1';

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

      -- GT loopback control
      loopback : in slv(2 downto 0);    -- GT Serial Loopback Control

      -- Debug
      debug : out slv(63 downto 0)
      );

end Pgp2Gtx7Fixedlat;


-- Define architecture
architecture rtl of Pgp2Gtx7Fixedlat is

   --------------------------------------------------------------------------------------------------
   -- Shared GT Signals
   --------------------------------------------------------------------------------------------------

   --------------------------------------------------------------------------------------------------
   -- Rx Signals
   --------------------------------------------------------------------------------------------------
   -- Rx Clocks

   -- Rx Resets
   signal gtRxResetDone  : sl;
   signal gtRxResetDoneL : sl;
   signal gtRxUserReset  : sl;

--   signal pgpRxResetInt  : sl;
--   signal pgpRxReset1    : sl;

   -- PgpRx Signals
   signal gtRxData      : slv(19 downto 0);  -- Feed to 8B10B decoder
   signal dataValid     : sl;           -- no decode or disparity errors
   signal phyRxLanesIn  : PgpRxPhyLaneInArray(0 to 0);   -- Output from decoder
   signal phyRxLanesOut : PgpRxPhyLaneOutArray(0 to 0);  -- Polarity to GT
   signal phyRxReady    : sl;           -- To RxRst
   signal phyRxInit     : sl;           -- To RxRst
   signal crcRxIn       : PgpCrcInType;
   signal crcRxOut      : slv(31 downto 0);

   -- CRC Rx IO (PgpRxPhy CRC IO must be adapted to V5 GT CRCs)
   signal crcRxWidthGtx7 : slv(2 downto 0);
   signal crcRxRstGtx7   : sl;
   signal crcRxInGtx7    : slv(31 downto 0);
   signal crcRxOutGtx7   : slv(31 downto 0);

   --------------------------------------------------------------------------------------------------
   -- Tx Signals
   --------------------------------------------------------------------------------------------------
   signal gtTxOutClk : sl;
   signal gtTxUsrClk : sl;

   signal gtTxResetDone : sl;

   -- PgpTx Signals
   signal phyTxLanesOut : PgpTxPhyLaneOutArray(0 to 0);
   signal phyTxReady    : sl;
   signal crcTxIn       : PgpCrcInType;
   signal crcTxOut      : slv(31 downto 0);

   -- CRC Tx IO (PgpTxPhy CRC IO must be adapted to K7 GT CRCs)
   signal crcTxWidthGtx7 : slv(2 downto 0);
   signal crcTxRstGtx7   : sl;
   signal crcTxInGtx7    : slv(31 downto 0);
   signal crcTxOutGtx7   : slv(31 downto 0);

begin

   --------------------------------------------------------------------------------------------------
   -- Rx Data Path
   -- Hold Decoder and PgpRx in reset until GtRxResetDone.
   --------------------------------------------------------------------------------------------------
   gtRxResetDoneL <= not gtRxResetDone;
   Decoder8b10b_1 : entity work.Decoder8b10b
      generic map (
         TPD_G          => TPD_G,
         RST_POLARITY_G => '0',         --active low polarity
         NUM_BYTES_G    => 2)
      port map (
         clk      => pgpRxClk,
         rst      => gtRxResetDone,
         dataIn   => gtRxData,
         dataOut  => phyRxLanesIn(0).data,
         dataKOut => phyRxLanesIn(0).dataK,
         codeErr  => phyRxLanesIn(0).decErr,
         dispErr  => phyRxLanesIn(0).dispErr);

   dataValid <= not (uOr(phyRxLanesIn(0).decErr) or uOr(phyRxLanesIn(0).dispErr));


   -- PGP RX Block
   Pgp2RxWrapper_1 : entity work.Pgp2RxWrapper
      generic map (
         RxLaneCnt    => 1,
         EnShortCells => EnShortCells)
      port map (
         pgpRxClk         => pgpRxClk,
         pgpRxReset       => gtRxResetDoneL,  -- Hold in reset until gtx rx is up
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         pgpVcRxCommonOut => pgpVcRxCommonOut,
         pgpVcRxQuadOut   => pgpVcRxQuadOut,
         phyRxLanesOut    => phyRxLanesOut,
         phyRxLanesIn     => phyRxLanesIn,
         phyRxReady       => gtRxResetDone,
         phyRxInit        => open,  --gtRxUserReset,        -- Ignore phyRxInit, rx will reset on its own
         crcRxIn          => crcRxIn,
         crcRxOut         => crcRxOut,
         debug            => open);

--   pgpRxResetInt <= pgpRxReset1 or pgpRxReset;

   -- RX CRC BLock
   -- Must adapt generic CRC type to GTX7 CRC block
   crcRxWidthGtx7            <= "001";
   crcRxRstGtx7              <= pgpRxReset or crcRxIn.init or not gtRxResetDone;
   crcRxInGtx7(31 downto 24) <= crcRxIn.crcIn(7 downto 0);
   crcRxInGtx7(23 downto 16) <= crcRxIn.crcIn(15 downto 8);
   crcRxInGtx7(15 downto 0)  <= (others => '0');
   crcRxOut                  <= not crcRxOutGtx7;  -- Invert Output CRC

   Rx_CRC : entity work.CRC32Rtl
      generic map(
         CRC_INIT => x"FFFFFFFF")
      port map(
         CRCOUT       => crcRxOutGtx7,
         CRCCLK       => pgpRxClk,
         CRCDATAVALID => crcRxIn.valid,
         CRCDATAWIDTH => crcRxWidthGtx7,
         CRCIN        => crcRxInGtx7,
         CRCRESET     => crcRxRstGtx7
         );

   pgpRxRecClkRst <= gtRxResetDoneL;

   --------------------------------------------------------------------------------------------------
   -- Tx Data Path
   --------------------------------------------------------------------------------------------------

   Pgp2TxWrapper_1 : entity work.Pgp2TxWrapper
      generic map (
         TxLaneCnt    => 1,
         VcInterleave => VcInterleave,
         NUM_VC_EN_G  => NUM_VC_EN_G)
      port map (
         pgpTxClk       => pgpTxClk,
         pgpTxReset     => pgpTxReset,
         pgpTxIn        => pgpTxIn,
         pgpTxOut       => pgpTxOut,
         pgpVcTxQuadIn  => pgpVcTxQuadIn,
         pgpVcTxQuadOut => pgpVcTxQuadOut,
         phyTxLanesOut  => phyTxLanesOut,
         phyTxReady     => gtTxResetDone,  --phyTxReady,  -- Use txResetDone
         crcTxIn        => crcTxIn,
         crcTxOut       => crcTxOut,
         debug          => open);

   -- Adapt CRC data width flag
   crcTxWidthGtx7            <= "001";
   crcTxRstGtx7              <= pgpTxReset or crcTxIn.init;
   -- Pass CRC data in on proper bits
   crcTxInGtx7(31 downto 24) <= crcTxIn.crcIn(7 downto 0);
   crcTxInGtx7(23 downto 16) <= crcTxIn.crcIn(15 downto 8);
   crcTxInGtx7(15 downto 0)  <= (others => '0');
   crcTxOut                  <= not crcTxOutGtx7;

   -- TX CRC BLock
   Tx_CRC : entity work.CRC32Rtl
      generic map(
         CRC_INIT => x"FFFFFFFF")
      port map(
         CRCOUT       => crcTxOutGtx7,
         CRCCLK       => pgpTxClk,
         CRCDATAVALID => crcTxIn.valid,
         CRCDATAWIDTH => crcTxWidthGtx7,
         CRCIN        => crcTxInGtx7,
         CRCRESET     => crcTxRstGtx7
         );

   -- Wrap txOutClk back to TxUsrClk to get sim to lock the alignment
--   TX_USR_CLK_BUFG : BUFG
--      port map (
--         I => gtTxOutClk,
--         O => gtTxUsrClk);
   gtTxUsrClk <= pgpTxClk;

   --------------------------------------------------------------------------------------------------
   -- GTX 7 Core in Fixed Latency mode
   --------------------------------------------------------------------------------------------------
   Gtx7Core_1 : entity work.Gtx7Core
      generic map (
         TPD_G                 => TPD_G,
         SIM_GTRESET_SPEEDUP_G => SIM_GTRESET_SPEEDUP_G,
         SIM_VERSION_G         => SIM_VERSION_G,
         SIMULATION_G          => SIMULATION_G,
         STABLE_CLOCK_PERIOD_G => STABLE_CLOCK_PERIOD_G,
         CPLL_REFCLK_SEL_G     => CPLL_REFCLK_SEL_G,
         CPLL_FBDIV_G          => CPLL_FBDIV_G,
         CPLL_FBDIV_45_G       => CPLL_FBDIV_45_G,
         CPLL_REFCLK_DIV_G     => CPLL_REFCLK_DIV_G,
         RXOUT_DIV_G           => RXOUT_DIV_G,
         TXOUT_DIV_G           => TXOUT_DIV_G,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_G,
--         PMA_RSV_G              => PMA_RSV_G,
         TX_PLL_G              => TX_PLL_G,
         RX_PLL_G              => RX_PLL_G,
         TX_EXT_DATA_WIDTH_G   => 16,
         TX_INT_DATA_WIDTH_G   => 20,
         TX_8B10B_EN_G         => true,
         RX_EXT_DATA_WIDTH_G   => 20,
         RX_INT_DATA_WIDTH_G   => 20,
         RX_8B10B_EN_G         => false,
         TX_BUF_EN_G           => false,
         TX_OUTCLK_SRC_G       => "PLLREFCLK",
         TX_DLY_BYPASS_G       => '0',
         TX_PHASE_ALIGN_G      => "MANUAL",
         RX_BUF_EN_G           => false,
         RX_OUTCLK_SRC_G       => "OUTCLKPMA",
         RX_USRCLK_SRC_G       => "RXOUTCLK",
         RX_DLY_BYPASS_G       => '1',
         RX_DDIEN_G            => '0',
         RX_ALIGN_MODE_G       => "FIXED_LAT",
         RX_DFE_KL_CFG2_G      => RX_DFE_KL_CFG2_G,
         RX_OS_CFG_G           => RX_OS_CFG_G,
         RXCDR_CFG_G           => RXCDR_CFG_G,
         RXDFEXYDEN_G          => RXDFEXYDEN_G,
--         ALIGN_COMMA_DOUBLE_G   => ALIGN_COMMA_DOUBLE_G,
--         ALIGN_COMMA_ENABLE_G   => ALIGN_COMMA_ENABLE_G,
--         ALIGN_COMMA_WORD_G     => ALIGN_COMMA_WORD_G,
--         ALIGN_MCOMMA_DET_G     => ALIGN_MCOMMA_DET_G,
--         ALIGN_MCOMMA_VALUE_G   => ALIGN_MCOMMA_VALUE_G,
--         ALIGN_MCOMMA_EN_G      => ALIGN_MCOMMA_EN_G,
--         ALIGN_PCOMMA_DET_G     => ALIGN_PCOMMA_DET_G,
--         ALIGN_PCOMMA_VALUE_G   => ALIGN_PCOMMA_VALUE_G,
--         ALIGN_PCOMMA_EN_G      => ALIGN_PCOMMA_EN_G,
--         SHOW_REALIGN_COMMA_G   => SHOW_REALIGN_COMMA_G,
         RXSLIDE_MODE_G        => "PMA",
         FIXED_ALIGN_COMMA_0_G => "----------0101111100",  -- Normal Comma
         FIXED_ALIGN_COMMA_1_G => "----------1010000011",  -- Inverted Comma
         FIXED_ALIGN_COMMA_2_G => "XXXXXXXXXXXXXXXXXXXX",  -- Unused
         FIXED_ALIGN_COMMA_3_G => "XXXXXXXXXXXXXXXXXXXX"   -- Unused
--         RX_DISPERR_SEQ_MATCH_G => RX_DISPERR_SEQ_MATCH_G,
--         DEC_MCOMMA_DETECT_G    => DEC_MCOMMA_DETECT_G,
--         DEC_PCOMMA_DETECT_G    => DEC_PCOMMA_DETECT_G,
--         DEC_VALID_COMMA_ONLY_G => DEC_VALID_COMMA_ONLY_G
         )
      port map (
         stableClkIn      => stableClk,
         cPllRefClkIn     => gtCPllRefClk,
         cPllLockOut      => gtCPllLock,
         qPllRefClkIn     => gtQPllRefClk,
         qPllClkIn        => gtQPllClk,
         qPllLockIn       => gtQPllLock,
         qPllRefClkLostIn => gtQPllRefClkLost,
         qPllResetOut     => gtQPllReset,
         gtRxRefClkBufg => gtRxRefClkBufg,
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         rxOutClkOut      => pgpRxRecClk,
         rxUsrClkIn       => pgpRxClk,
         rxUsrClk2In      => pgpRxClk,
         rxUserRdyOut     => open,  -- rx clock locked and stable, but alignment not yet done
         rxMmcmResetOut   => pgpRxMmcmReset,
         rxMmcmLockedIn   => pgpRxMmcmLocked,
         rxUserResetIn    => pgpRxReset,
         rxResetDoneOut   => gtRxResetDone,  -- Use for rxRecClkReset???
         rxDataValidIn    => dataValid,   -- From 8b10b
         rxSlideIn        => '0',       -- Slide is controlled internally
         rxDataOut        => gtRxData,
         rxCharIsKOut     => open,      -- Not using gt rx 8b10b
         rxDecErrOut      => open,      -- Not using gt rx 8b10b
         rxDispErrOut     => open,      -- Not using gt rx 8b10b
         rxPolarityIn     => phyRxLanesOut(0).polarity,
         rxBufStatusOut   => open,      -- Not using rx buff
         txOutClkOut      => gtTxOutClk,  -- Maybe drive PGP TX with this and output it
         txUsrClkIn       => gtTxUsrClk,
         txUsrClk2In      => gtTxUsrClk,
         txUserRdyOut     => open,      -- Not sure what to do with this
         txMmcmResetOut   => open,      -- No Tx MMCM in Fixed Latency mode
         txMmcmLockedIn   => '1',
         txUserResetIn    => pgpTxReset,
         txResetDoneOut   => gtTxResetDone,
         txDataIn         => phyTxLanesOut(0).data,
         txCharIsKIn      => phyTxLanesOut(0).dataK,
         txBufStatusOut   => open,      -- Not using tx buff
         loopbackIn       => loopback);

end rtl;

