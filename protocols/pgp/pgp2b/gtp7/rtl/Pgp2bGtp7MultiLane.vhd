-------------------------------------------------------------------------------
-- File       : Pgp2bGtp7MultiLane.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-29
-- Last update: 2016-08-24
-------------------------------------------------------------------------------
-- Description: Gtp7 Variable Latency, multi-lane Module
-------------------------------------------------------------------------------
-- This file is part of 'SLAC Firmware Standard Library'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC Firmware Standard Library', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp2bGtp7MultiLane is
   generic (
      TPD_G                 : time                 := 1 ns;
      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string               := "FALSE";
      SIM_VERSION_G         : string               := "1.0";
      STABLE_CLOCK_PERIOD_G : real                 := 4.0E-9;                    --units of seconds
      -- Configure PLL 
      RXOUT_DIV_G           : integer              := 2;
      TXOUT_DIV_G           : integer              := 2;
      RX_CLK25_DIV_G        : integer              := 7;      -- Set by wizard
      TX_CLK25_DIV_G        : integer              := 7;      -- Set by wizard
      PMA_RSV_G             : bit_vector           := x"00000333";               -- Set by wizard
      RX_OS_CFG_G           : bit_vector           := "0001111110000";           -- Set by wizard
      RXCDR_CFG_G           : bit_vector           := x"0000107FE206001041010";  -- Set by wizard
      RXLPM_INCM_CFG_G      : bit                  := '1';    -- Set by wizard
      RXLPM_IPCM_CFG_G      : bit                  := '0';    -- Set by wizard      
      TX_PLL_G              : string               := "PLL0";
      RX_PLL_G              : string               := "PLL1";
      -- Configure Buffer usage
      TX_BUF_EN_G           : boolean              := true;
      TX_OUTCLK_SRC_G       : string               := "OUTCLKPMA";
      TX_DLY_BYPASS_G       : sl                   := '1';
      TX_PHASE_ALIGN_G      : string               := "NONE";
      TX_BUF_ADDR_MODE_G    : string               := "FULL";
      -- Configure Number of Lanes
      LANE_CNT_G            : integer range 1 to 2 := 1;
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      VC_INTERLEAVE_G       : integer              := 0;      -- No interleave Frames
      PAYLOAD_CNT_TOP_G     : integer              := 7;      -- Top bit for payload counter
      NUM_VC_EN_G           : integer range 1 to 4 := 4;
      AXI_ERROR_RESP_G      : slv(1 downto 0)      := AXI_RESP_DECERR_C;
      TX_ENABLE_G           : boolean              := true;   -- Enable TX direction
      RX_ENABLE_G           : boolean              := true);  -- Enable RX direction
   port (
      -- GT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      gtQPllOutRefClk  : in  slv(1 downto 0);
      gtQPllOutClk     : in  slv(1 downto 0);
      gtQPllLock       : in  slv(1 downto 0);
      gtQPllRefClkLost : in  slv(1 downto 0);
      gtQPllReset      : out slv(1 downto 0);
      -- Gt Serial IO
      gtTxP            : out slv((LANE_CNT_G-1) downto 0);    -- GT Serial Transmit Positive
      gtTxN            : out slv((LANE_CNT_G-1) downto 0);    -- GT Serial Transmit Negative
      gtRxP            : in  slv((LANE_CNT_G-1) downto 0);    -- GT Serial Receive Positive
      gtRxN            : in  slv((LANE_CNT_G-1) downto 0);    -- GT Serial Receive Negative
      -- Tx Clocking
      pgpTxReset       : in  sl;
      pgpTxRecClk      : out sl;        -- recovered clock      
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
      pgpRxIn          : in  Pgp2bRxInType;
      pgpRxOut         : out Pgp2bRxOutType;
      -- Non VC Tx Signals
      pgpTxIn          : in  Pgp2bTxInType;
      pgpTxOut         : out Pgp2bTxOutType;
      -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
      pgpTxMasters     : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves      : out AxiStreamSlaveArray(3 downto 0);
      -- Frame Receive Interface - 1 Lane, Array of 4 VCs
      pgpRxMasters     : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed : out AxiStreamMasterType;
      pgpRxCtrl        : in  AxiStreamCtrlArray(3 downto 0);

      -- Debug Interface 
      txPreCursor      : in  slv(4 downto 0)                                  := (others => '0');
      txPostCursor     : in  slv(4 downto 0)                                  := (others => '0');
      txDiffCtrl       : in  slv(3 downto 0)                                  := "1000";
      -- AXI-Lite Interface 
      axilClk          : in  sl                                               := '0';
      axilRst          : in  sl                                               := '0';
      axilReadMasters  : in  AxiLiteReadMasterArray((LANE_CNT_G-1) downto 0)  := (others => AXI_LITE_READ_MASTER_INIT_C);
      axilReadSlaves   : out AxiLiteReadSlaveArray((LANE_CNT_G-1) downto 0);
      axilWriteMasters : in  AxiLiteWriteMasterArray((LANE_CNT_G-1) downto 0) := (others => AXI_LITE_WRITE_MASTER_INIT_C);
      axilWriteSlaves  : out AxiLiteWriteSlaveArray((LANE_CNT_G-1) downto 0));      

end Pgp2bGtp7MultiLane;

-- Define architecture
architecture rtl of Pgp2bGtp7MultiLane is
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
   signal phyRxLanesIn    : Pgp2bRxPhyLaneInArray((LANE_CNT_G-1) downto 0);
   signal phyRxLanesOut   : Pgp2bRxPhyLaneOutArray((LANE_CNT_G-1) downto 0);
   signal phyRxReady      : sl;
   signal phyRxInit       : sl;

   -- Rx Channel Bonding
   signal rxChBondLevel : slv(2 downto 0);
   signal rxChBondIn    : Slv4Array(LANE_CNT_G-1 downto 0);
   signal rxChBondOut   : Slv4Array(LANE_CNT_G-1 downto 0);

   -- PgpTx Signals
   signal pgpTxMmcmResets : slv((LANE_CNT_G-1) downto 0);
   signal pgpTxRecClock   : slv((LANE_CNT_G-1) downto 0);
   signal gtTxResetDone   : slv((LANE_CNT_G-1) downto 0);
   signal gtTxUserResetIn : sl;
   signal phyTxLanesOut   : Pgp2bTxPhyLaneOutArray((LANE_CNT_G-1) downto 0);
   signal phyTxReady      : sl;

   signal stableRst : sl;
   signal drpGnt    : slv(LANE_CNT_G-1 downto 0);
   signal drpRdy    : slv(LANE_CNT_G-1 downto 0);
   signal drpEn     : slv(LANE_CNT_G-1 downto 0);
   signal drpWe     : slv(LANE_CNT_G-1 downto 0);
   signal drpAddr   : Slv9Array(LANE_CNT_G-1 downto 0);
   signal drpDi     : Slv16Array(LANE_CNT_G-1 downto 0);
   signal drpDo     : Slv16Array(LANE_CNT_G-1 downto 0);
   
begin

   gtQPllReset    <= gtQPllResets(0);
   pgpTxMmcmReset <= pgpTxMmcmResets(0);
   pgpRxMmcmReset <= pgpRxMmcmResets(0);
   pgpRxRecClk    <= pgpRxRecClock(0);
   pgpTxRecClk    <= pgpTxRecClock(0);

   phyTxReady <= uAnd(gtTxResetDone);
   phyRxReady <= uAnd(gtRxResetDone);

   gtRxUserResetIn <= gtRxUserReset or pgpRxReset;
   gtTxUserResetIn <= pgpTxReset;

   U_Pgp2bLane : entity work.Pgp2bLane
      generic map (
         TPD_G             => TPD_G,
         LANE_CNT_G        => 1,
         VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G       => NUM_VC_EN_G,
         TX_ENABLE_G       => TX_ENABLE_G,
         RX_ENABLE_G       => RX_ENABLE_G)
      port map (
         pgpTxClk         => pgpTxClk,
         pgpTxClkRst      => pgpTxReset,
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         phyTxLanesOut    => phyTxLanesOut,
         phyTxReady       => phyTxReady,
         pgpRxClk         => pgpRxClk,
         pgpRxClkRst      => pgpRxReset,
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         pgpRxMasters     => pgpRxMasters,
         pgpRxMasterMuxed => pgpRxMasterMuxed,
         pgpRxCtrl        => pgpRxCtrl,
         phyRxLanesOut    => phyRxLanesOut,
         phyRxLanesIn     => phyRxLanesIn,
         phyRxReady       => phyRxReady,
         phyRxInit        => gtRxUserReset
         );

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
            TX_BUF_EN_G              => TX_BUF_EN_G,
            TX_OUTCLK_SRC_G          => TX_OUTCLK_SRC_G,
            TX_DLY_BYPASS_G          => TX_DLY_BYPASS_G,
            TX_PHASE_ALIGN_G         => TX_PHASE_ALIGN_G,
            TX_BUF_ADDR_MODE_G       => TX_BUF_ADDR_MODE_G,
            RX_BUF_EN_G              => true,
            RX_OUTCLK_SRC_G          => "OUTCLKPMA",
            RX_USRCLK_SRC_G          => "RXOUTCLK",    -- Not 100% sure, doesn't really matter
            RX_DLY_BYPASS_G          => '1',
            RX_DDIEN_G               => '0',
            RX_BUF_ADDR_MODE_G       => "FULL",
            RX_ALIGN_MODE_G          => "GT",          -- Default
            ALIGN_COMMA_DOUBLE_G     => "FALSE",       -- Default
            ALIGN_COMMA_ENABLE_G     => "1111111111",  -- Default
            ALIGN_COMMA_WORD_G       => 2,             -- Default
            ALIGN_MCOMMA_DET_G       => "TRUE",
            ALIGN_MCOMMA_VALUE_G     => "1010000011",  -- Default
            ALIGN_MCOMMA_EN_G        => '1',
            ALIGN_PCOMMA_DET_G       => "TRUE",
            ALIGN_PCOMMA_VALUE_G     => "0101111100",  -- Default
            ALIGN_PCOMMA_EN_G        => '1',
            SHOW_REALIGN_COMMA_G     => "FALSE",
            RXSLIDE_MODE_G           => "AUTO",
            RX_DISPERR_SEQ_MATCH_G   => "TRUE",        -- Default
            DEC_MCOMMA_DETECT_G      => "TRUE",        -- Default
            DEC_PCOMMA_DETECT_G      => "TRUE",        -- Default
            DEC_VALID_COMMA_ONLY_G   => "FALSE",       -- Default
            CBCC_DATA_SOURCE_SEL_G   => "DECODED",     -- Default
            CLK_COR_SEQ_2_USE_G      => "FALSE",       -- Default
            CLK_COR_KEEP_IDLE_G      => "FALSE",       -- Default
            CLK_COR_MAX_LAT_G        => 21,
            CLK_COR_MIN_LAT_G        => 18,
            CLK_COR_PRECEDENCE_G     => "TRUE",        -- Default
            CLK_COR_REPEAT_WAIT_G    => 0,             -- Default
            CLK_COR_SEQ_LEN_G        => 4,
            CLK_COR_SEQ_1_ENABLE_G   => "1111",        -- Default
            CLK_COR_SEQ_1_1_G        => "0110111100",
            CLK_COR_SEQ_1_2_G        => "0100011100",
            CLK_COR_SEQ_1_3_G        => "0100011100",
            CLK_COR_SEQ_1_4_G        => "0100011100",
            CLK_CORRECT_USE_G        => "TRUE",
            CLK_COR_SEQ_2_ENABLE_G   => "0000",        -- Default
            CLK_COR_SEQ_2_1_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_2_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_3_G        => "0000000000",  -- Default
            CLK_COR_SEQ_2_4_G        => "0000000000",  -- Default
            RX_CHAN_BOND_EN_G        => true,
            RX_CHAN_BOND_MASTER_G    => (i = 0),
            CHAN_BOND_KEEP_ALIGN_G   => "FALSE",       -- Default
            CHAN_BOND_MAX_SKEW_G     => 10,
            CHAN_BOND_SEQ_LEN_G      => 1,             -- Default
            CHAN_BOND_SEQ_1_1_G      => "0110111100",
            CHAN_BOND_SEQ_1_2_G      => "0111011100",
            CHAN_BOND_SEQ_1_3_G      => "0111011100",
            CHAN_BOND_SEQ_1_4_G      => "0111011100",
            CHAN_BOND_SEQ_1_ENABLE_G => "1111",        -- Default
            CHAN_BOND_SEQ_2_1_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_2_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_3_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_4_G      => "0000000000",  -- Default
            CHAN_BOND_SEQ_2_ENABLE_G => "0000",        -- Default
            CHAN_BOND_SEQ_2_USE_G    => "FALSE",       -- Default
            FTS_DESKEW_SEQ_ENABLE_G  => "1111",        -- Default
            FTS_LANE_DESKEW_CFG_G    => "1111",        -- Default
            FTS_LANE_DESKEW_EN_G     => "FALSE")       -- Default
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
            txOutClkOut      => pgpTxRecClock(i),
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
            loopbackIn       => pgpRxIn.loopback,
            txPreCursor      => txPreCursor,
            txPostCursor     => txPostCursor,
            txDiffCtrl       => txDiffCtrl,
            drpGnt           => drpGnt(i),
            drpRdy           => drpRdy(i),
            drpEn            => drpEn(i),
            drpWe            => drpWe(i),
            drpAddr          => drpAddr(i),
            drpDi            => drpDi(i),
            drpDo            => drpDo(i));            

      U_AxiLiteToDrp : entity work.AxiLiteToDrp
         generic map (
            TPD_G            => TPD_G,
            AXI_ERROR_RESP_G => AXI_ERROR_RESP_G,
            COMMON_CLK_G     => false,
            EN_ARBITRATION_G => true,
            TIMEOUT_G        => 4096,
            ADDR_WIDTH_G     => 9,
            DATA_WIDTH_G     => 16)      
         port map (
            -- AXI-Lite Port
            axilClk         => axilClk,
            axilRst         => axilRst,
            axilReadMaster  => axilReadMasters(i),
            axilReadSlave   => axilReadSlaves(i),
            axilWriteMaster => axilWriteMasters(i),
            axilWriteSlave  => axilWriteSlaves(i),
            -- DRP Interface
            drpClk          => stableClk,
            drpRst          => stableRst,
            drpGnt          => drpGnt(i),
            drpRdy          => drpRdy(i),
            drpEn           => drpEn(i),
            drpWe           => drpWe(i),
            drpAddr         => drpAddr(i),
            drpDi           => drpDi(i),
            drpDo           => drpDo(i));            

   end generate GTP7_CORE_GEN;

   U_RstSync : entity work.RstSync
      generic map (
         TPD_G => TPD_G)      
      port map (
         clk      => stableClk,
         asyncRst => axilRst,
         syncRst  => stableRst);     

end rtl;
