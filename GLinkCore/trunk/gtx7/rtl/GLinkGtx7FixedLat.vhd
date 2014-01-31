-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : GLinkGtx7FixedLat.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-30
-- Last update: 2014-01-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.StdRtlPkg.all;
use work.GlinkPkg.all;

entity GLinkGtx7FixedLat is
   generic (
      -- Simulation Generics
      TPD_G                 : time       := 1 ns;
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "4.0";
      SIMULATION_G          : boolean    := false;
      -- CPLL Settings
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      CPLL_FBDIV_G          : integer    := 4;
      CPLL_FBDIV_45_G       : integer    := 5;
      CPLL_REFCLK_DIV_G     : integer    := 1;
      -- MGT Settings
      RXOUT_DIV_G           : integer    := 2;
      TXOUT_DIV_G           : integer    := 2;
      RX_CLK25_DIV_G        : integer    := 5;                -- Set by wizard
      TX_CLK25_DIV_G        : integer    := 5;                -- Set by wizard
      RX_OS_CFG_G           : bit_vector := "0000010000000";  -- Set by wizard
      RXCDR_CFG_G           : bit_vector := x"03000023ff40200020";  -- Set by wizard
      RXDFEXYDEN_G          : sl         := '0';              -- Set by wizard
      RX_DFE_KL_CFG2_G      : bit_vector := x"3008E56A";      -- Set by wizard
      -- Configure PLL sources
      TX_PLL_G              : string     := "QPLL";
      RX_PLL_G              : string     := "CPLL");
   port (
      -- TX Signals
      gLinkTx          : in  GLinkTxType;
      txClk            : in  sl;
      txRst            : in  sl;
      -- RX Signals
      gLinkRx          : out GLinkRxType;
      rxClk            : in  sl;-- Run recClk through external MMCM and sent to this input
      rxRecClk         : out sl;-- recovered clock
      rxRst            : in  sl;
      rxMmcmRst        : out sl;
      rxMmcmLocked     : in  sl := '1';
      -- MGT Clocking
      stableClk        : in  sl;-- GT needs a stable clock to "boot up"
      gtCPllRefClk     : in  sl := '0';-- Drives CPLL if used
      gtCPllLock       : out sl;
      gtQPllRefClk     : in  sl := '0';-- Signals from QPLL if used
      gtQPllClk        : in  sl := '0';
      gtQPllLock       : in  sl := '0';
      gtQPllRefClkLost : in  sl := '0';
      gtQPllReset      : out sl;
      -- MGT loopback control
      loopback         : in  slv(2 downto 0);
      -- MGT Serial IO
      gtTxP            : out sl;
      gtTxN            : out sl;
      gtRxP            : in  sl;
      gtRxN            : in  sl);

end GLinkGtx7FixedLat;

architecture rtl of GLinkGtx7FixedLat is
   
   constant FIXED_ALIGN_COMMA_0_C : slv(19 downto 0) := x"FF003";  --FF0
   constant FIXED_ALIGN_COMMA_1_C : slv(19 downto 0) := x"FE003";  --FF1A
   constant FIXED_ALIGN_COMMA_2_C : slv(19 downto 0) := x"FF803";  --FF1B

   signal gtTxRstDone,
      gtRxRstDone,
      decoderError,
      dataValid : sl;
   signal gtTxData,
      gtRxData : slv(19 downto 0);

begin
   
   GLinkEncoder_Inst : entity work.GLinkEncoder
      generic map (
         RST_POLARITY_G => '0')  
      port map (
         clk         => txClk,
         rst         => gtTxRstDone,
         idle        => gLinkTx.idle,
         control     => gLinkTx.control,
         rawData     => gLinkTx.data,
         encodedData => gtTxData);

   GLinkDecoder_Inst : entity work.GLinkDecoder
      generic map (
         RST_POLARITY_G => '0')  
      port map (
         clk          => rxClk,
         rst          => gtRxRstDone,
         gtRxData     => gtRxData,
         decodedData  => gLinkRx.data,
         isControl    => gLinkRx.isControl,
         isData       => gLinkRx.isData,
         isIdle       => gLinkRx.isIdle,
         flag         => gLinkRx.flag,
         decoderError => decoderError);

   dataValid <= not(decoderError);

   -- GTX 7 Core in Fixed Latency mode
   Gtx7Core_Inst : entity work.Gtx7Core
      generic map (
         TPD_G                 => TPD_G,
         SIM_GTRESET_SPEEDUP_G => SIM_GTRESET_SPEEDUP_G,
         SIM_VERSION_G         => SIM_VERSION_G,
         SIMULATION_G          => SIMULATION_G,
         STABLE_CLOCK_PERIOD_G => 4.0E-9,
         CPLL_REFCLK_SEL_G     => CPLL_REFCLK_SEL_G,
         CPLL_FBDIV_G          => CPLL_FBDIV_G,
         CPLL_FBDIV_45_G       => CPLL_FBDIV_45_G,
         CPLL_REFCLK_DIV_G     => CPLL_REFCLK_DIV_G,
         RXOUT_DIV_G           => RXOUT_DIV_G,
         TXOUT_DIV_G           => TXOUT_DIV_G,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_G,
         TX_PLL_G              => TX_PLL_G,
         RX_PLL_G              => RX_PLL_G,
         TX_EXT_DATA_WIDTH_G   => 20,
         TX_INT_DATA_WIDTH_G   => 20,
         TX_8B10B_EN_G         => false,
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
         RXSLIDE_MODE_G        => "PMA",
         FIXED_COMMA_EN_G      => "0111",
         FIXED_ALIGN_COMMA_0_G => FIXED_ALIGN_COMMA_0_C,
         FIXED_ALIGN_COMMA_1_G => FIXED_ALIGN_COMMA_1_C,
         FIXED_ALIGN_COMMA_2_G => FIXED_ALIGN_COMMA_2_C,
         FIXED_ALIGN_COMMA_3_G => "XXXXXXXXXXXXXXXXXXXX")
      port map (
         stableClkIn      => stableClk,
         cPllRefClkIn     => gtCPllRefClk,
         cPllLockOut      => gtCPllLock,
         qPllRefClkIn     => gtQPllRefClk,
         qPllClkIn        => gtQPllClk,
         qPllLockIn       => gtQPllLock,
         qPllRefClkLostIn => gtQPllRefClkLost,
         qPllResetOut     => gtQPllReset,
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         rxRefClkOut      => open,
         rxOutClkOut      => rxRecClk,
         rxUsrClkIn       => rxClk,
         rxUsrClk2In      => rxClk,
         rxUserRdyOut     => open,
         rxMmcmResetOut   => rxMmcmRst,
         rxMmcmLockedIn   => rxMmcmLocked,
         rxUserResetIn    => rxRst,
         rxResetDoneOut   => gtRxRstDone,
         rxDataValidIn    => dataValid,
         rxSlideIn        => '0',       -- Slide is controlled internally
         rxDataOut        => gtRxData,
         rxCharIsKOut     => open,      -- Not using gt rx 8b10b
         rxDecErrOut      => open,      -- Not using gt rx 8b10b
         rxDispErrOut     => open,      -- Not using gt rx 8b10b
         rxPolarityIn     => '0',
         rxBufStatusOut   => open,
         txRefClkOut      => open,
         txOutClkOut      => open,
         txOutClkPcsOut   => open,
         txUsrClkIn       => txClk,
         txUsrClk2In      => txClk,
         txUserRdyOut     => open,      -- Not sure what to do with this
         txMmcmResetOut   => open,      -- No Tx MMCM in Fixed Latency mode
         txMmcmLockedIn   => '1',
         txUserResetIn    => txRst,
         txResetDoneOut   => gtTxRstDone,
         txDataIn         => gtTxData,
         txCharIsKIn      => (others => '0'),  -- Not using gt rx 8b10b
         txBufStatusOut   => open,
         loopbackIn       => loopback);

end rtl;
