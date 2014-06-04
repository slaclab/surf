-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2Gtp7MultiLane.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2014-06-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gtp7 Wrapper
--
-- Dependencies:  ^/pgp2_core/trunk/rtl/core/Pgp2RxWrapper.vhd
--                ^/pgp2_core/trunk/rtl/core/Pgp2TxWrapper.vhd
--                ^/StdLib/trunk/rtl/CRC32Rtl.vhd
--                ^/MgtLib/trunk/rtl/gtp7/Gtp7Core.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Pgp2CoreTypesPkg.all;
use work.StdRtlPkg.all;
use work.VcPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp2Gtp7MultiLane is
   generic (
      TPD_G                 : time                 := 1 ns;
      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string               := "FALSE";
      SIM_VERSION_G         : string               := "1.0";
      STABLE_CLOCK_PERIOD_G : real                 := 4.0E-9;  --units of seconds
      -- Configure PLL 
      RXOUT_DIV_G           : integer              := 2;
      TXOUT_DIV_G           : integer              := 2;
      RX_CLK25_DIV_G        : integer              := 7;  -- Set by wizard
      TX_CLK25_DIV_G        : integer              := 7;  -- Set by wizard
      PMA_RSV_G             : bit_vector           := x"00000333";  -- Set by wizard
      RX_OS_CFG_G           : bit_vector           := "0001111110000";  -- Set by wizard
      RXCDR_CFG_G           : bit_vector           := x"0000107FE206001041010";  -- Set by wizard
      RXLPM_INCM_CFG_G      : bit                  := '1';  -- Set by wizard
      RXLPM_IPCM_CFG_G      : bit                  := '0';  -- Set by wizard      
      TX_PLL_G              : string               := "PLL0";
      RX_PLL_G              : string               := "PLL1";
      -- Configure Number of Lanes
      LANE_CNT_G            : integer range 1 to 4 := 1;
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PayloadCntTop         : integer              := 7;  -- Top bit for payload counter
      EnShortCells          : integer              := 1;  -- Enable short non-EOF cells
      VcInterleave          : integer              := 1;  -- Interleave Frames
      NUM_VC_EN_G : integer range 1 to 4 := 4
      );
   port (
      -- GT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      gtQPllOutRefClk  : in  slv(1 downto 0);
      gtQPllOutClk     : in  slv(1 downto 0);
      gtQPllLock       : in  slv(1 downto 0);
      gtQPllRefClkLost : in  slv(1 downto 0);
      gtQPllReset      : out slv(1 downto 0);
      -- Gt Serial IO
      gtTxP            : out slv((LANE_CNT_G-1) downto 0);  -- GT Serial Transmit Positive
      gtTxN            : out slv((LANE_CNT_G-1) downto 0);  -- GT Serial Transmit Negative
      gtRxP            : in  slv((LANE_CNT_G-1) downto 0);  -- GT Serial Receive Positive
      gtRxN            : in  slv((LANE_CNT_G-1) downto 0);  -- GT Serial Receive Negative
      -- Tx Clocking
      pgpTxReset       : in  sl;
      pgpTxClk         : in  sl;
      pgpTxMmcmReset   : out sl;
      pgpTxMmcmLocked  : in  sl;
      -- Rx clocking
      pgpRxReset       : in  sl;
      pgpRxRecClk      : out sl;        -- recovered clock      
      pgpRxClk         : in  sl;
      pgpRxMmcmReset   : out sl;
      pgpRxMmcmLocked  : in  sl;
      -- Non VC Rx Signals
      pgpRxIn          : in  PgpRxInType;
      pgpRxOut         : out PgpRxOutType;
      -- Non VC Tx Signals
      pgpTxIn          : in  PgpTxInType;
      pgpTxOut         : out PgpTxOutType;
      -- Frame Transmit Interface - Array of 4 VCs
      pgpVcTxQuadIn    : in  VcTxQuadInType;
      pgpVcTxQuadOut   : out VcTxQuadOutType;
      -- Frame Receive Interface - Array of 4 VCs
      pgpVcRxCommonOut : out VcRxCommonOutType;
      pgpVcRxQuadOut   : out VcRxQuadOutType;
      -- GT loopback control
      loopback         : in  slv(2 downto 0));

end Pgp2Gtp7MultiLane;

-- Define architecture
architecture rtl of Pgp2Gtp7MultiLane is
   --------------------------------------------------------------------------------------------------
   -- Types
   --------------------------------------------------------------------------------------------------
   type QPllResetsVector is array (integer range<>) of slv(1 downto 0);

   --------------------------------------------------------------------------------------------------
   -- Constants
   --------------------------------------------------------------------------------------------------
   signal gtQPllResets : QPllResetsVector((LANE_CNT_G-1) downto 0);

   -- PgpRx Signals
   signal pgpRxMmcmResets : slv((LANE_CNT_G-1) downto 0);
   signal pgpRxRecClock   : slv((LANE_CNT_G-1) downto 0);
   signal gtRxResetDone   : slv((LANE_CNT_G-1) downto 0);
   signal gtRxUserReset   : sl;
   signal gtRxUserResetIn : sl;
   signal phyRxLanesIn    : PgpRxPhyLaneInArray((LANE_CNT_G-1) downto 0);
   signal phyRxLanesOut   : PgpRxPhyLaneOutArray((LANE_CNT_G-1) downto 0);
   signal phyRxReady      : sl;
   signal phyRxInit       : sl;
   signal crcRxIn         : PgpCrcInType;
   signal crcRxOut        : slv(31 downto 0);

   -- CRC Rx IO (PgpRxPhy CRC IO must be adapted to V5 GT CRCs)
   signal crcRxWidthGtp7 : slv(2 downto 0);
   signal crcRxRstGtp7   : sl;
   signal crcRxInGtp7    : slv(31 downto 0);
   signal crcRxOutGtp7   : slv(31 downto 0);

   -- Rx Channel Bonding
   signal rxChBondLevel : slv(2 downto 0);
   signal rxChBondIn    : Slv4Array(LANE_CNT_G-1 downto 0);
   signal rxChBondOut   : Slv4Array(LANE_CNT_G-1 downto 0);

   -- PgpTx Signals
   signal pgpTxMmcmResets : slv((LANE_CNT_G-1) downto 0);
   signal gtTxResetDone   : slv((LANE_CNT_G-1) downto 0);
   signal gtTxUserResetIn : sl;
   signal phyTxLanesOut   : PgpTxPhyLaneOutArray((LANE_CNT_G-1) downto 0);
   signal phyTxReady      : sl;
   signal crcTxIn         : PgpCrcInType;
   signal crcTxOut        : slv(31 downto 0);

   -- CRC Tx IO (PgpTxPhy CRC IO must be adapted to K7 GT CRCs)
   signal crcTxWidthGtp7 : slv(2 downto 0);
   signal crcTxRstGtp7   : sl;
   signal crcTxInGtp7    : slv(31 downto 0);
   signal crcTxOutGtp7   : slv(31 downto 0);

begin

   gtQPllReset    <= gtQPllResets(0);
   pgpTxMmcmReset <= pgpTxMmcmResets(0);
   pgpRxMmcmReset <= pgpRxMmcmResets(0);
   pgpRxRecClk    <= pgpRxRecClock(0);

   phyTxReady <= uAnd(gtTxResetDone);
   phyRxReady <= uAnd(gtRxResetDone);

   gtRxUserResetIn <= gtRxUserReset or pgpRxReset;
   gtTxUserResetIn <= pgpTxReset;

   -- PGP RX Block
   Pgp2RxWrapper_1 : entity work.Pgp2RxWrapper
      generic map (
         RxLaneCnt     => LANE_CNT_G,
         EnShortCells  => EnShortCells,
         PayloadCntTop => PayloadCntTop)
      port map (
         pgpRxClk         => pgpRxClk,
         pgpRxReset       => pgpRxReset,
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         pgpVcRxCommonOut => pgpVcRxCommonOut,
         pgpVcRxQuadOut   => pgpVcRxQuadOut,
         phyRxLanesOut    => phyRxLanesOut,
         phyRxLanesIn     => phyRxLanesIn,
         phyRxReady       => phyRxReady,
         phyRxInit        => gtRxUserReset,
         crcRxIn          => crcRxIn,
         crcRxOut         => crcRxOut,
         debug            => open);

   -- RX CRC BLock
   crcRxRstGtp7              <= pgpRxReset or crcRxIn.init or not phyRxReady;
   crcRxInGtp7(31 downto 24) <= crcRxIn.crcIn(7 downto 0);
   crcRxInGtp7(23 downto 16) <= crcRxIn.crcIn(15 downto 8);
   CRC_RX_1xLANE : if LANE_CNT_G = 1 generate
      crcRxWidthGtp7           <= "001";
      crcRxInGtp7(15 downto 0) <= (others => '0');
   end generate CRC_RX_1xLANE;
   CRC_RX_2xLANE : if LANE_CNT_G = 2 generate
      crcRxWidthGtp7           <= "011";
      crcRxInGtp7(15 downto 8) <= crcRxIn.crcIn(23 downto 16);
      crcRxInGtp7(7 downto 0)  <= crcRxIn.crcIn(31 downto 24);
   end generate CRC_RX_2xLANE;
   CRC_RX_3xLANE : if LANE_CNT_G = 3 generate
      crcRxWidthGtp7           <= "011";
      crcRxInGtp7(15 downto 8) <= crcRxIn.crcIn(23 downto 16);
      crcRxInGtp7(7 downto 0)  <= crcRxIn.crcIn(31 downto 24);
   end generate CRC_RX_3xLANE;
   CRC_RX_4xLANE : if LANE_CNT_G = 4 generate
      crcRxWidthGtp7           <= "011";
      crcRxInGtp7(15 downto 8) <= crcRxIn.crcIn(23 downto 16);
      crcRxInGtp7(7 downto 0)  <= crcRxIn.crcIn(31 downto 24);
   end generate CRC_RX_4xLANE;
   crcRxOut <= not crcRxOutGtp7;

   Rx_CRC : entity work.CRC32Rtl
      generic map(
         CRC_INIT => x"FFFFFFFF")
      port map(
         CRCOUT       => crcRxOutGtp7,
         CRCCLK       => pgpRxClk,
         CRCDATAVALID => crcRxIn.valid,
         CRCDATAWIDTH => crcRxWidthGtp7,
         CRCIN        => crcRxInGtp7,
         CRCRESET     => crcRxRstGtp7);

   -- PGP TX Block
   Pgp2TxWrapper_1 : entity work.Pgp2TxWrapper
      generic map (
         TxLaneCnt     => LANE_CNT_G,
         VcInterleave  => VcInterleave,
         PayloadCntTop => PayloadCntTop,
         NUM_VC_EN_G => NUM_VC_EN_G)
      port map (
         pgpTxClk       => pgpTxClk,
         pgpTxReset     => pgpTxReset,
         pgpTxIn        => pgpTxIn,
         pgpTxOut       => pgpTxOut,
         pgpVcTxQuadIn  => pgpVcTxQuadIn,
         pgpVcTxQuadOut => pgpVcTxQuadOut,
         phyTxLanesOut  => phyTxLanesOut,
         phyTxReady     => phyTxReady,
         crcTxIn        => crcTxIn,
         crcTxOut       => crcTxOut,
         debug          => open);

   -- TX CRC BLock
   crcTxRstGtp7              <= pgpTxReset or crcTxIn.init;
   crcTxInGtp7(31 downto 24) <= crcTxIn.crcIn(7 downto 0);
   crcTxInGtp7(23 downto 16) <= crcTxIn.crcIn(15 downto 8);
   CRC_TX_1xLANE : if LANE_CNT_G = 1 generate
      crcTxWidthGtp7           <= "001";
      crcTxInGtp7(15 downto 0) <= (others => '0');
   end generate CRC_TX_1xLANE;
   CRC_TX_2xLANE : if LANE_CNT_G = 2 generate
      crcTxWidthGtp7           <= "011";
      crcTxInGtp7(15 downto 8) <= crcTxIn.crcIn(23 downto 16);
      crcTxInGtp7(7 downto 0)  <= crcTxIn.crcIn(31 downto 24);
   end generate CRC_TX_2xLANE;
   CRC_TX_3xLANE : if LANE_CNT_G = 3 generate
      crcTxWidthGtp7           <= "011";
      crcTxInGtp7(15 downto 8) <= crcTxIn.crcIn(23 downto 16);
      crcTxInGtp7(7 downto 0)  <= crcTxIn.crcIn(31 downto 24);
   end generate CRC_TX_3xLANE;
   CRC_TX_4xLANE : if LANE_CNT_G = 4 generate
      crcTxWidthGtp7           <= "011";
      crcTxInGtp7(15 downto 8) <= crcTxIn.crcIn(23 downto 16);
      crcTxInGtp7(7 downto 0)  <= crcTxIn.crcIn(31 downto 24);
   end generate CRC_TX_4xLANE;
   crcTxOut <= not crcTxOutGtp7;

   Tx_CRC : entity work.CRC32Rtl
      generic map(
         CRC_INIT => x"FFFFFFFF")
      port map(
         CRCOUT       => crcTxOutGtp7,
         CRCCLK       => pgpTxClk,
         CRCDATAVALID => crcTxIn.valid,
         CRCDATAWIDTH => crcTxWidthGtp7,
         CRCIN        => crcTxInGtp7,
         CRCRESET     => crcTxRstGtp7);

   --------------------------------------------------------------------------------------------------
   -- Generate the GTP channels
   --------------------------------------------------------------------------------------------------
   GTP7_CORE_GEN : for i in (LANE_CNT_G-1) downto 0 generate
      -- Channel Bonding
--      gtp(i).rxChBondLevel         <= conv_std_logic_vector((LANE_CNT_G-1-i), 3);
      Bond_Master : if (i = 0) generate
         rxChBondIn(i) <= "0000";
      end generate Bond_Master;
      Bond_Slaves : if (i /= 0) generate
         rxChBondIn(i) <= rxChBondOut(i-1);
      end generate Bond_Slaves;

      Gtp7Core_Inst : entity work.Gtp7Core
         generic map (
            TPD_G                    => TPD_G,
            SIM_GTRESET_SPEEDUP_G    => SIM_GTRESET_SPEEDUP_G,
            SIM_VERSION_G            => SIM_VERSION_G,
            STABLE_CLOCK_PERIOD_G    => STABLE_CLOCK_PERIOD_G,
            RXOUT_DIV_G              => RXOUT_DIV_G,
            TXOUT_DIV_G              => TXOUT_DIV_G,
            RX_CLK25_DIV_G           => RX_CLK25_DIV_G,
            TX_CLK25_DIV_G           => TX_CLK25_DIV_G,
            PMA_RSV_G                => PMA_RSV_G,
            RX_OS_CFG_G              => RX_OS_CFG_G,
            RXCDR_CFG_G              => RXCDR_CFG_G,
            RXLPM_INCM_CFG_G         => RXLPM_INCM_CFG_G,
            RXLPM_IPCM_CFG_G         => RXLPM_IPCM_CFG_G,
            TX_PLL_G                 => TX_PLL_G,
            RX_PLL_G                 => RX_PLL_G,
            TX_EXT_DATA_WIDTH_G      => 16,
            TX_INT_DATA_WIDTH_G      => 20,
            TX_8B10B_EN_G            => true,
            RX_EXT_DATA_WIDTH_G      => 16,
            RX_INT_DATA_WIDTH_G      => 20,
            RX_8B10B_EN_G            => true,
            TX_BUF_EN_G              => true,
            TX_OUTCLK_SRC_G          => "OUTCLKPMA",
            TX_DLY_BYPASS_G          => '1',
            TX_PHASE_ALIGN_G         => "NONE",
            TX_BUF_ADDR_MODE_G       => "FULL",
            RX_BUF_EN_G              => true,
            RX_OUTCLK_SRC_G          => "OUTCLKPMA",
            RX_USRCLK_SRC_G          => "RXOUTCLK",  -- Not 100% sure, doesn't really matter
            RX_DLY_BYPASS_G          => '1',
            RX_DDIEN_G               => '0',
            RX_BUF_ADDR_MODE_G       => "FULL",
            RX_ALIGN_MODE_G          => "GT",        -- Default
            ALIGN_COMMA_DOUBLE_G     => "FALSE",     -- Default
            ALIGN_COMMA_ENABLE_G     => "1111111111",  -- Default
            ALIGN_COMMA_WORD_G       => 2,           -- Default
            ALIGN_MCOMMA_DET_G       => "TRUE",
            ALIGN_MCOMMA_VALUE_G     => "1010000011",  -- Default
            ALIGN_MCOMMA_EN_G        => '1',
            ALIGN_PCOMMA_DET_G       => "TRUE",
            ALIGN_PCOMMA_VALUE_G     => "0101111100",  -- Default
            ALIGN_PCOMMA_EN_G        => '1',
            SHOW_REALIGN_COMMA_G     => "FALSE",
            RXSLIDE_MODE_G           => "AUTO",
            RX_DISPERR_SEQ_MATCH_G   => "TRUE",      -- Default
            DEC_MCOMMA_DETECT_G      => "TRUE",      -- Default
            DEC_PCOMMA_DETECT_G      => "TRUE",      -- Default
            DEC_VALID_COMMA_ONLY_G   => "FALSE",     -- Default
            CBCC_DATA_SOURCE_SEL_G   => "DECODED",   -- Default
            CLK_COR_SEQ_2_USE_G      => "FALSE",     -- Default
            CLK_COR_KEEP_IDLE_G      => "FALSE",     -- Default
            CLK_COR_MAX_LAT_G        => 21,
            CLK_COR_MIN_LAT_G        => 18,
            CLK_COR_PRECEDENCE_G     => "TRUE",      -- Default
            CLK_COR_REPEAT_WAIT_G    => 0,           -- Default
            CLK_COR_SEQ_LEN_G        => 4,
            CLK_COR_SEQ_1_ENABLE_G   => "1111",      -- Default
            CLK_COR_SEQ_1_1_G        => "0110111100",
            CLK_COR_SEQ_1_2_G        => "0100011100",
            CLK_COR_SEQ_1_3_G        => "0100011100",
            CLK_COR_SEQ_1_4_G        => "0100011100",
            CLK_CORRECT_USE_G        => "TRUE",
            CLK_COR_SEQ_2_ENABLE_G   => "0000",      -- Default
            CLK_COR_SEQ_2_1_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_2_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_3_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_4_G        => "0000000000",  -- Default
            RX_CHAN_BOND_EN_G        => true,
            RX_CHAN_BOND_MASTER_G    => (i = 0),
            CHAN_BOND_KEEP_ALIGN_G   => "FALSE",     -- Default
            CHAN_BOND_MAX_SKEW_G     => 10,
            CHAN_BOND_SEQ_LEN_G      => 1,           -- Default
            CHAN_BOND_SEQ_1_1_G      => "0110111100",
            CHAN_BOND_SEQ_1_2_G      => "0111011100",
            CHAN_BOND_SEQ_1_3_G      => "0111011100",
            CHAN_BOND_SEQ_1_4_G      => "0111011100",
            CHAN_BOND_SEQ_1_ENABLE_G => "1111",      -- Default
            CHAN_BOND_SEQ_2_1_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_2_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_3_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_4_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_ENABLE_G => "0000",      -- Default
            CHAN_BOND_SEQ_2_USE_G    => "FALSE",     -- Default
            FTS_DESKEW_SEQ_ENABLE_G  => "1111",      -- Default
            FTS_LANE_DESKEW_CFG_G    => "1111",      -- Default
            FTS_LANE_DESKEW_EN_G     => "FALSE")     -- Default
         port map (
            stableClkIn      => stableClk,
            qPllRefClkIn     => gtQPllOutRefClk,
            qPllClkIn        => gtQPllOutClk,
            qPllLockIn       => gtQPllLock,
            qPllRefClkLostIn => gtQPllRefClkLost,
            qPllResetOut     => gtQPllResets(i),
            gtTxP            => gtTxP(i),
            gtTxN            => gtTxN(i),
            gtRxP            => gtRxP(i),
            gtRxN            => gtRxN(i),
            rxOutClkOut      => pgpRxRecClock(i),
            rxUsrClkIn       => pgpRxClk,
            rxUsrClk2In      => pgpRxClk,
            rxUserRdyOut     => open,
            rxMmcmResetOut   => pgpRxMmcmResets(i),
            rxMmcmLockedIn   => pgpRxMmcmLocked,
            rxUserResetIn    => gtRxUserResetIn,
            rxResetDoneOut   => gtRxResetDone(i),
            rxDataValidIn    => '1',
            rxSlideIn        => '0',
            rxDataOut        => phyRxLanesIn(i).data,
            rxCharIsKOut     => phyRxLanesIn(i).dataK,
            rxDecErrOut      => phyRxLanesIn(i).decErr,
            rxDispErrOut     => phyRxLanesIn(i).dispErr,
            rxPolarityIn     => phyRxLanesOut(i).polarity,
            rxBufStatusOut   => open,
            rxChBondLevelIn  => slv(to_unsigned((LANE_CNT_G-1-i), 3)),
            rxChBondIn       => rxChBondIn(i),
            rxChBondOut      => rxChBondOut(i),
            txOutClkOut      => open,
            txUsrClkIn       => pgpTxClk,
            txUsrClk2In      => pgpTxClk,
            txUserRdyOut     => open,
            txMmcmResetOut   => pgpTxMmcmResets(i),
            txMmcmLockedIn   => pgpTxMmcmLocked,
            txUserResetIn    => gtTxUserResetIn,
            txResetDoneOut   => gtTxResetDone(i),
            txDataIn         => phyTxLanesOut(i).data,
            txCharIsKIn      => phyTxLanesOut(i).dataK,
            txBufStatusOut   => open,
            loopbackIn       => loopback);
   end generate GTP7_CORE_GEN;
end rtl;
