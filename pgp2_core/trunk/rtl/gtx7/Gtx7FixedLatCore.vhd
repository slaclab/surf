-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Gtx7FixedLatCore.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2012-12-12
-- Last update: 2012-12-20
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2012 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Gtx7FixedLatCore is
  
  generic (
    TPD_G : time := 1 ns;

    -- Simulation attributes --
    SIM_GTRESET_SPEEDUP_G : string := "false";
    SIM_VERSION_G         : string := "4.0";

    -- CPLL Settings --
    REFCLK_PERIOD_G   : time       := 8 ns;
    CPLL_REFCLK_SEL_G : bit_vector := "001";
    CPLL_FBDIV_G      : integer    := 4;
    CPLL_FBDIV_45_G   : integer    := 5;
    CPLL_REFCLK_DIV_G : integer    := 1;
    RXOUT_DIV_G       : integer    := 2;
    TXOUT_DIV_G       : integer    := 2;

    -- ???
    PMA_RSV_G : bit_vector := x"001E7080";  -- or 00018480

    -- Configure PLL sources
    TX_PLL_G : string := "CPLL";
    RX_PLL_G : string := "QPLL"
    );

  port (
    refClkIn : in sl;                   -- Drives CPLL if used and reset logic

    -- QPLL signals (may be unused depending on PLL configuration)
    qPllRefClkIn : in  sl := '0';
    qPllClkIn    : in  sl := '0';
    qPllLockIn   : in  sl := '0';
    qPllResetOut : out sl;

    -- GT Serial IO
    gtTxP : out sl;
    gtTxN : out sl;
    gtRxP : in  sl;
    gtRxN : in  sl;

    -- Rx Clock related signals
    rxOutClkOut    : out sl;
    rxUsrClkIn     : in  sl;
    rxUserRdyOut   : out sl;
    rxMmcmResetOut : out sl;
    rxMmcmLockedIn : in  sl := '1';

    -- Rx User Reset Signals
    rxUserResetIn  : in  sl;
    rxResetDoneOut : out sl;

    -- Rx Data and decode signals
    rxDataOut      : out slv(15 downto 0);
    rxCharIsKOut   : out slv(1 downto 0);
    rxDecErrOut    : out slv(1 downto 0);
    rxDispErrOut   : out slv(1 downto 0);
    rxPolarityIn   : in  sl := '0';
    rxBufStatusOut : out slv(2 downto 0);

    -- Tx Clock Related Signals
    txOutClkOut    : out sl;
    txUsrClkIn     : in  sl;
    txUserRdyOut   : out sl;
    txMmcmResetOut : out sl;
    txMmcmLockedIn : in  sl := '1';

    txUserResetIn  : in  sl;
    txResetDoneOut : out sl;

    -- Tx Data
    txDataIn       : in  slv(15 downto 0);
    txCharIsKIn    : in  slv(1 downto 0);
    txBufStatusOut : out slv(1 downto 0);

    loopbackIn : in slv(2 downto 0) := "000"
    );

end entity Gtx7FixedLatCore;

architecture rtl of Gtx7FixedLatCore is

  signal rxUserRdyInt     : sl;
  signal rxDataRaw        : slv(19 downto 0);
  signal rxDecErrInt      : slv(1 downto 0);
  signal rxDispErrInt     : slv(1 downto 0);
  signal rxDecodeErr      : sl;
  signal rxDataValid      : sl;
  signal rxSlide          : sl;
  signal rxAlignUserReset : sl;
  signal rxUserReset      : sl;
  
begin

  rxUserRdyOut <= rxUserRdyInt;
  rxDecErrOut  <= rxDecErrInt;
  rxDispErrOut <= rxDispErrInt;

  --------------------------------------------------------------------------------------------------
  -- Rx 8B10B Decoder
  --------------------------------------------------------------------------------------------------
  Decoder8b10b_1 : entity work.Decoder8b10b
    generic map (
      TPD_G       => TPD_G,
      NUM_BYTES_G => 2)
    port map (
      clk      => rxUsrClkIn,
      rstN     => rxUserRdyInt,
      dataIn   => rxDataRaw,
      dataOut  => rxDataOut,
      dataKOut => rxCharIsKOut,
      codeErr  => rxDecErrInt,
      dispErr  => rxDispErrInt);

  --------------------------------------------------------------------------------------------------
  -- Rx Comma Aligner
  --------------------------------------------------------------------------------------------------
  rxDecodeErr <= uOr(rxDecErrInt or rxDispErrInt);
  Gtx7RxCommaAligner_1 : entity work.Gtx7RxCommaAligner
    generic map (
      TPD_G            => TPD_G,
      WORD_SIZE_G      => 20,
      COMMA_0_G        => "----------0101111100",
      COMMA_1_G        => "----------1010000011",
      COMMA_2_G        => "XXXXXXXXXXXXXXXXXXXX",
      COMMA_3_G        => "XXXXXXXXXXXXXXXXXXXX",
      SLIDE_WAIT_G     => 32,
      MAX_DECODE_ERR_G => 32)
    port map (
      rxUsrClk    => rxUsrClkIn,
      rxUserRdy   => rxUserRdyInt,      -- Needs to be synchronized to usrClk
      rxData      => rxDataRaw,
      decodeErr   => rxDecodeErr,
      rxSlide     => rxSlide,
      rxUserReset => rxAlignUserReset,
      aligned     => rxDataValid);

  rxUserReset <= rxUserResetIn or rxAlignUserReset;

  Gtx7Core_1 : entity work.Gtx7Core
    generic map (
      TPD_G                 => TPD_G,
      SIM_GTRESET_SPEEDUP_G => SIM_GTRESET_SPEEDUP_G,
      SIM_VERSION_G         => SIM_VERSION_G,
      REFCLK_PERIOD_G       => REFCLK_PERIOD_G,
      CPLL_REFCLK_SEL_G     => CPLL_REFCLK_SEL_G,
      CPLL_FBDIV_G          => CPLL_FBDIV_G,
      CPLL_FBDIV_45_G       => CPLL_FBDIV_45_G,
      CPLL_REFCLK_DIV_G     => CPLL_REFCLK_DIV_G,
      RXOUT_DIV_G           => RXOUT_DIV_G,
      TXOUT_DIV_G           => TXOUT_DIV_G,
      PMA_RSV_G             => PMA_RSV_G,
      TX_PLL_G              => TX_PLL_G,
      RX_PLL_G              => RX_PLL_G,
      TX_EXT_DATA_WIDTH_G   => 16,
      TX_INT_DATA_WIDTH_G   => 20,
      TX_8B10B_EN_G         => true,
      RX_EXT_DATA_WIDTH_G   => 20,
      RX_INT_DATA_WIDTH_G   => 20,
      RX_8B10B_EN_G         => false,
      TX_BUF_EN_G           => true,
      TX_OUTCLK_SRC_G       => "PLLREFCLK",
      TX_DLY_BYPASS_G       => '1',
      RX_BUF_EN_G           => false, 
      RX_OUTCLK_SRC_G       => "OUTCLKPMA",
      RX_USRCLK_SRC_G       => "RXOUTCLK",
      RX_DLY_BYPASS_G       => '1',
      RX_DDIEN_G            => '0',
      RXSLIDE_MODE_G        => "PMA"
      )
    port map (
      refClkIn       => refClkIn,
      qPllRefClkIn   => qPllRefClkIn,
      qPllClkIn      => qPllClkIn,
      qPllLockIn     => qPllLockIn,
      qPllResetOut   => qPllResetOut,
      gtTxP          => gtTxP,
      gtTxN          => gtTxN,
      gtRxP          => gtRxP,
      gtRxN          => gtRxN,
      rxOutClkOut    => rxOutClkOut,
      rxUsrClkIn     => rxUsrClkIn,
      rxUsrClk2In    => rxUsrClkIn,
      rxUserRdyOut   => rxUserRdyInt,
      rxMmcmResetOut => rxMmcmResetOut,
      rxMmcmLockedIn => rxMmcmLockedIn,
      rxUserResetIn  => rxUserReset,
      rxResetDoneOut => rxResetDoneOut,
      rxDataValidIn  => rxDataValid,
      rxSlideIn      => rxSlide,
      rxDataOut      => rxDataRaw,
      rxCharIsKOut   => open,
      rxDecErrOut    => open,
      rxDispErrOut   => open,
      rxPolarityIn   => rxPolarityIn,
      rxBufStatusOut => rxBufStatusOut,
      txOutClkOut    => txOutClkOut,
      txUsrClkIn     => txUsrClkIn,
      txUsrClk2In    => txUsrClkIn,
      txUserRdyOut   => txUserRdyOut,
      txMmcmResetOut => txMmcmResetOut,
      txMmcmLockedIn => txMmcmLockedIn,
      txUserResetIn  => txUserResetIn,
      txResetDoneOut => txResetDoneOut,
      txDataIn       => txDataIn,
      txCharIsKIn    => txCharIsKIn,
      txBufStatusOut => txBufStatusOut,
      loopbackIn     => loopbackIn);

end architecture rtl;
