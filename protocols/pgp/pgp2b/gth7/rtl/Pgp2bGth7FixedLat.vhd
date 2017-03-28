-------------------------------------------------------------------------------
-- File       : Pgp2bGth7Fixedlat.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-01
-- Last update: 2016-08-24
-------------------------------------------------------------------------------
-- Description: Gth7 Fixed Latency Module
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

use work.StdRtlPkg.all;
use work.Pgp2bPkg.all;
use work.AxiStreamPkg.all;
use work.AxiLitePkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Pgp2bGth7Fixedlat is
   generic (
      TPD_G : time := 1 ns;

      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics --
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "2.0";
      SIMULATION_G          : boolean    := false;
      STABLE_CLOCK_PERIOD_G : real       := 4.0E-9;  --units of seconds
      -- CPLL Settings - Defaults to 2.5 Gbps operation 
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      CPLL_FBDIV_G          : integer    := 4;
      CPLL_FBDIV_45_G       : integer    := 5;
      CPLL_REFCLK_DIV_G     : integer    := 1;
      RXOUT_DIV_G           : integer    := 2;
      TXOUT_DIV_G           : integer    := 2;
      RX_CLK25_DIV_G        : integer    := 5;
      TX_CLK25_DIV_G        : integer    := 5;

      PMA_RSV_G    : bit_vector := x"00000080";
      RX_OS_CFG_G  : bit_vector := "0000010000000";           -- Set by wizard
      RXCDR_CFG_G  : bit_vector := x"0002007FE1000C2200018";  -- Set by wizard
      RXDFEXYDEN_G : sl         := '0';                       -- Set by wizard

      -- Configure PLL sources
      TX_PLL_G : string := "QPLL";
      RX_PLL_G : string := "CPLL";

      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      VC_INTERLEAVE_G   : integer              := 0;      -- No interleave Frames
      PAYLOAD_CNT_TOP_G : integer              := 7;      -- Top bit for payload counter
      NUM_VC_EN_G       : integer range 1 to 4 := 4;
      AXI_ERROR_RESP_G  : slv(1 downto 0)      := AXI_RESP_DECERR_C;
      TX_ENABLE_G       : boolean              := true;   -- Enable TX direction
      RX_ENABLE_G       : boolean              := true);  -- Enable RX direction
   port (
      -- GT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      gtCPllRefClk     : in  sl := '0';                   -- Drives CPLL if used
      gtCPllLock       : out sl;
      gtQPllRefClk     : in  sl := '0';                   -- Signals from QPLL if used
      gtQPllClk        : in  sl := '0';
      gtQPllLock       : in  sl := '0';
      gtQPllRefClkLost : in  sl := '0';
      gtQPllReset      : out sl;
      gtRxRefClkBufg   : in  sl;        -- gtrefclk driving rx side, fed through clock buffer

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
      pgpRxClk        : in  sl;         -- Run recClk through external MMCM and sent to this input
      pgpRxMmcmReset  : out sl;
      pgpRxMmcmLocked : in  sl := '1';

      -- Non VC Rx Signals
      pgpRxIn  : in  Pgp2bRxInType;
      pgpRxOut : out Pgp2bRxOutType;

      -- Non VC Tx Signals
      pgpTxIn  : in  Pgp2bTxInType;
      pgpTxOut : out Pgp2bTxOutType;

      -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
      pgpTxMasters : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves  : out AxiStreamSlaveArray(3 downto 0);

      -- Frame Receive Interface - 1 Lane, Array of 4 VCs
      pgpRxMasters     : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed : out AxiStreamMasterType;
      pgpRxCtrl        : in  AxiStreamCtrlArray(3 downto 0);

      -- Debug Interface 
      txPreCursor     : in  slv(4 downto 0)        := (others => '0');
      txPostCursor    : in  slv(4 downto 0)        := (others => '0');
      txDiffCtrl      : in  slv(3 downto 0)        := "1000";
      -- AXI-Lite Interface 
      axilClk         : in  sl                     := '0';
      axilRst         : in  sl                     := '0';
      axilReadMaster  : in  AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave   : out AxiLiteReadSlaveType;
      axilWriteMaster : in  AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave  : out AxiLiteWriteSlaveType);

end Pgp2bGth7Fixedlat;


-- Define architecture
architecture rtl of Pgp2bGth7Fixedlat is

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
   signal gtRxData      : slv(19 downto 0);                -- Feed to 8B10B decoder
   signal dataValid     : sl;                              -- no decode or disparity errors
   signal phyRxLanesIn  : Pgp2bRxPhyLaneInArray(0 to 0);   -- Output from decoder
   signal phyRxLanesOut : Pgp2bRxPhyLaneOutArray(0 to 0);  -- Polarity to GT
   signal phyRxReady    : sl;                              -- To RxRst
   signal phyRxInit     : sl;                              -- To RxRst

   --------------------------------------------------------------------------------------------------
   -- Tx Signals
   --------------------------------------------------------------------------------------------------
   signal gtTxOutClk : sl;
   signal gtTxUsrClk : sl;

   signal gtTxResetDone : sl;

   -- PgpTx Signals
   signal phyTxLanesOut : Pgp2bTxPhyLaneOutArray(0 to 0);
   signal phyTxReady    : sl;

   signal stableRst : sl;
   signal drpGnt    : sl;
   signal drpRdy    : sl;
   signal drpEn     : sl;
   signal drpWe     : sl;
   signal drpAddr   : slv(8 downto 0);
   signal drpDi     : slv(15 downto 0);
   signal drpDo     : slv(15 downto 0);
   
begin

   --------------------------------------------------------------------------------------------------
   -- PGP Core
   --------------------------------------------------------------------------------------------------

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
         phyTxReady       => gtTxResetDone,  --phyTxReady,  -- Use txResetDone
         pgpRxClk         => pgpRxClk,
         pgpRxClkRst      => gtRxResetDoneL,  -- Hold in reset until gtp rx is up
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         pgpRxMasters     => pgpRxMasters,
         pgpRxMasterMuxed => pgpRxMasterMuxed,
         pgpRxCtrl        => pgpRxCtrl,
         phyRxLanesOut    => phyRxLanesOut,
         phyRxLanesIn     => phyRxLanesIn,
         phyRxReady       => gtRxResetDone,
         phyRxInit        => open  --gtRxUserReset,        -- Ignore phyRxInit, rx will reset on its own
         );

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

--   pgpRxResetInt <= pgpRxReset1 or pgpRxReset;

   pgpRxRecClkRst <= gtRxResetDoneL;

   --------------------------------------------------------------------------------------------------
   -- Tx Data Path
   --------------------------------------------------------------------------------------------------

   -- Wrap txOutClk back to TxUsrClk to get sim to lock the alignment
--   TX_USR_CLK_BUFG : BUFG
--      port map (
--         I => gtTxOutClk,
--         O => gtTxUsrClk);
   gtTxUsrClk <= pgpTxClk;

   --------------------------------------------------------------------------------------------------
   -- GTX 7 Core in Fixed Latency mode
   --------------------------------------------------------------------------------------------------
   Gth7Core_1 : entity work.Gth7Core
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
         RX_OS_CFG_G           => RX_OS_CFG_G,
         RXCDR_CFG_G           => RXCDR_CFG_G,
         RXDFEXYDEN_G          => RXDFEXYDEN_G,
         RX_EQUALIZER_G        => "DFE",
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
         gtRxRefClkBufg   => gtRxRefClkBufg,
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         rxOutClkOut      => pgpRxRecClk,
         rxUsrClkIn       => pgpRxClk,
         rxUsrClk2In      => pgpRxClk,
         rxUserRdyOut     => open,      -- rx clock locked and stable, but alignment not yet done
         rxMmcmResetOut   => pgpRxMmcmReset,
         rxMmcmLockedIn   => pgpRxMmcmLocked,
         rxUserResetIn    => pgpRxReset,
         rxResetDoneOut   => gtRxResetDone,                -- Use for rxRecClkReset???
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
         loopbackIn       => pgpRxIn.loopback,
         txPreCursor      => txPreCursor,
         txPostCursor     => txPostCursor,
         txDiffCtrl       => txDiffCtrl,
         drpGnt           => drpGnt,
         drpRdy           => drpRdy,
         drpEn            => drpEn,
         drpWe            => drpWe,
         drpAddr          => drpAddr,
         drpDi            => drpDi,
         drpDo            => drpDo);            

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
         axilReadMaster  => axilReadMaster,
         axilReadSlave   => axilReadSlave,
         axilWriteMaster => axilWriteMaster,
         axilWriteSlave  => axilWriteSlave,
         -- DRP Interface
         drpClk          => stableClk,
         drpRst          => stableRst,
         drpGnt          => drpGnt,
         drpRdy          => drpRdy,
         drpEn           => drpEn,
         drpWe           => drpWe,
         drpAddr         => drpAddr,
         drpDi           => drpDi,
         drpDo           => drpDo);

   U_RstSync : entity work.RstSync
      generic map (
         TPD_G => TPD_G)      
      port map (
         clk      => stableClk,
         asyncRst => axilRst,
         syncRst  => stableRst); 

end rtl;

