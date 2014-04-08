-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2bGtx7MultiLane.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2014-01-29
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
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.Vc64Pkg.all;
use work.Pgp2bPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp2bGtx7MultiLane is
   generic (
      TPD_G                 : time       := 1 ns;
      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "4.0";
      STABLE_CLOCK_PERIOD_G : real       := 6.4E-9;  --units of seconds
      -- CPLL Settings
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      CPLL_FBDIV_G          : integer    := 4;
      CPLL_FBDIV_45_G       : integer    := 5;
      CPLL_REFCLK_DIV_G     : integer    := 1;
      RXOUT_DIV_G           : integer    := 2;
      TXOUT_DIV_G           : integer    := 2;
      RX_CLK25_DIV_G        : integer    := 7;
      TX_CLK25_DIV_G        : integer    := 7;

      RX_OS_CFG_G  : bit_vector := "0000010000000";        -- Set by wizard
      RXCDR_CFG_G  : bit_vector := x"03000023ff40200020";  -- Set by wizard
      RXDFEXYDEN_G : sl         := '0';                    -- Set by wizard

      -- RX Equalizer Attributes
      RX_DFE_KL_CFG2_G : bit_vector := x"3010D90C";  -- Set by wizard
      -- Configure PLL sources
      TX_PLL_G         : string     := "QPLL";
      RX_PLL_G         : string     := "CPLL";

      -- Configure Number of Lanes
      LANE_CNT_G    : integer range 1 to 2 := 2;
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PAYLOAD_CNT_TOP_G : integer := 7;  -- Top bit for payload counter
      EN_SHORT_CELLS_G  : integer := 1;      -- Enable short non-EOF cells
      VC_INTERLEAVE_G   : integer := 1;      -- Interleave Frames
      NUM_VC_EN_G       : integer range 1 to 4 := 4
      );
   port (
      -- GT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      gtCPllRefClk     : in  sl;        -- Drives CPLL if used
      gtCPllLock       : out sl;
      gtQPllRefClk     : in  sl;        -- Signals from QPLL if used
      gtQPllClk        : in  sl;
      gtQPllLock       : in  sl;
      gtQPllRefClkLost : in  sl;
      gtQPllReset      : out sl;
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
      -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
      pgpTxVcData      : in  Vc64DataArray(3 downto 0);
      pgpTxVcCtrl      : out Vc64CtrlArray(3 downto 0);
      -- Frame Receive Interface - 1 Lane, Array of 4 VCs
      pgpRxVcData      : out Vc64DataType;
      pgpRxVcCtrl      : in  Vc64CtrlArray(3 downto 0);
      -- GT loopback control
      loopback         : in  slv(2 downto 0));
end Pgp2bGtx7MultiLane;

-- Define architecture
architecture rtl of Pgp2bGtx7MultiLane is
   --------------------------------------------------------------------------------------------------
   -- Constants
   --------------------------------------------------------------------------------------------------
   signal gtQPllResets : slv((LANE_CNT_G-1) downto 0);

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

   -- Rx Channel Bonding
   signal rxChBondLevel : slv(2 downto 0);
   signal rxChBondIn    : Slv5Array(LANE_CNT_G-1 downto 0);
   signal rxChBondOut   : Slv5Array(LANE_CNT_G-1 downto 0);

   -- PgpTx Signals
   signal pgpTxMmcmResets : slv((LANE_CNT_G-1) downto 0);
   signal gtTxResetDone   : slv((LANE_CNT_G-1) downto 0);
   signal gtTxUserResetIn : sl;
   signal phyTxLanesOut   : PgpTxPhyLaneOutArray((LANE_CNT_G-1) downto 0);
   signal phyTxReady      : sl;

begin

   gtQPllReset    <= gtQPllResets(0);
   pgpTxMmcmReset <= pgpTxMmcmResets(0);
   pgpRxMmcmReset <= pgpRxMmcmResets(0);
   pgpRxRecClk    <= pgpRxRecClock(0);

   phyTxReady <= uAnd(gtTxResetDone);
   phyRxReady <= uAnd(gtRxResetDone);

   gtRxUserResetIn <= gtRxUserReset or pgpRxReset;
   gtTxUserResetIn <= pgpTxReset;

   U_Pgp2bLane: entity work.Pgp2bLane 
      generic map (
         LANE_CNT_G        => LANE_CNT_G,
         VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
         EN_SHORT_CELLS_G  => EN_SHORT_CELLS_G,
         PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G       => NUM_VC_EN_G
      ) port map ( 
         pgpTxClk           => pgpTxClk,
         pgpTxClkRst        => pgpTxReset,
         pgpTxIn            => pgpTxIn,
         pgpTxOut           => pgpTxOut,
         pgpTxVcData        => pgpTxVcData,
         pgpTxVcCtrl        => pgpTxVcCtrl,
         phyTxLanesOut      => phyTxLanesOut,
         phyTxReady         => phyTxReady,
         pgpRxClk           => pgpRxClk,
         pgpRxClkRst        => pgpRxReset,
         pgpRxIn            => pgpRxIn,
         pgpRxOut           => pgpRxOut,
         pgpRxVcData        => pgpRxVcData,
         pgpRxVcCtrl        => pgpRxVcCtrl,
         phyRxLanesOut      => phyRxLanesOut,
         phyRxLanesIn       => phyRxLanesIn,
         phyRxReady         => phyRxReady,
         phyRxInit          => gtRxUserReset
      );

   --------------------------------------------------------------------------------------------------
   -- Generate the GTX channels
   --------------------------------------------------------------------------------------------------
   GTX7_CORE_GEN : for i in (LANE_CNT_G-1) downto 0 generate
      -- Channel Bonding
--      gtx(i).rxChBondLevel         <= conv_std_logic_vector((LANE_CNT_G-1-i), 3);
      Bond_Master : if (i = 0) generate
         rxChBondIn(i) <= "00000";
      end generate Bond_Master;
      Bond_Slaves : if (i /= 0) generate
         rxChBondIn(i) <= rxChBondOut(i-1);
      end generate Bond_Slaves;

      Gtx7Core_Inst : entity work.Gtx7Core
         generic map (
            TPD_G                    => TPD_G,
            SIM_GTRESET_SPEEDUP_G    => SIM_GTRESET_SPEEDUP_G,
            SIM_VERSION_G            => SIM_VERSION_G,
            STABLE_CLOCK_PERIOD_G    => STABLE_CLOCK_PERIOD_G,
            CPLL_REFCLK_SEL_G        => CPLL_REFCLK_SEL_G,
            CPLL_FBDIV_G             => CPLL_FBDIV_G,
            CPLL_FBDIV_45_G          => CPLL_FBDIV_45_G,
            CPLL_REFCLK_DIV_G        => CPLL_REFCLK_DIV_G,
            RXOUT_DIV_G              => RXOUT_DIV_G,
            TXOUT_DIV_G              => TXOUT_DIV_G,
            RX_CLK25_DIV_G           => RX_CLK25_DIV_G,
            TX_CLK25_DIV_G           => TX_CLK25_DIV_G,
            PMA_RSV_G                => x"00018480",
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
            FTS_LANE_DESKEW_EN_G     => "FALSE",     -- Default
            RX_OS_CFG_G              => RX_OS_CFG_G,
            RXCDR_CFG_G              => RXCDR_CFG_G,
            RXDFEXYDEN_G             => RXDFEXYDEN_G,
            RX_DFE_KL_CFG2_G         => RX_DFE_KL_CFG2_G)
         port map (
            stableClkIn      => stableClk,
            cPllRefClkIn     => gtCPllRefClk,
            cPllLockOut      => gtCPllLock,
            qPllRefClkIn     => gtQPllRefClk,
            qPllClkIn        => gtQPllClk,
            qPllLockIn       => gtQPllLock,
            qPllRefClkLostIn => gtQPllRefClkLost,
            qPllResetOut     => gtQPllResets(i),
            gtTxP            => gtTxP(i),
            gtTxN            => gtTxN(i),
            gtRxP            => gtRxP(i),
            gtRxN            => gtRxN(i),
            rxRefClkOut      => open,
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
            txRefClkOut      => open,
            txOutClkOut      => open,
            txOutClkPcsOut   => open,
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


   end generate GTX7_CORE_GEN;
end rtl;
