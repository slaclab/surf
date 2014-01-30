-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : GLinkGtp7FixedLat.vhd
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

entity GLinkGtp7FixedLat is
   generic (
      -- Simulation Generics
      TPD_G                 : time       := 1 ns;
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "4.0";
      SIMULATION_G          : boolean    := false;
      -- MGT Settings
      RXOUT_DIV_G           : integer    := 2;
      TXOUT_DIV_G           : integer    := 2;
      RX_CLK25_DIV_G        : integer    := 5;    -- Set by wizard
      TX_CLK25_DIV_G        : integer    := 5;    -- Set by wizard
      PMA_RSV_G             : bit_vector := x"00000333";      -- Set by wizard
      RX_OS_CFG_G           : bit_vector := "0001111110000";  -- Set by wizard
      RXCDR_CFG_G           : bit_vector := x"0000107FE206001041010";  -- Set by wizard
      RXLPM_INCM_CFG_G      : bit        := '1';  -- Set by wizard
      RXLPM_IPCM_CFG_G      : bit        := '0';  -- Set by wizard         
      -- Configure PLL sources
      TX_PLL_G              : string     := "PLL0";
      RX_PLL_G              : string     := "PLL1");
   port (
      -- TX Data Interface from FPGA
      txDataIn         : in  slv(15 downto 0);
      txIdle           : in  sl;
      txControl        : in  sl;
      -- RX Data Interface to FPGA
      rxDataOut        : out slv(15 downto 0);
      rxIsControl      : out sl;
      rxIsData         : out sl;
      rxIsIdle         : out sl;
      rxFlag           : out sl;
      -- TX Clocking
      txRst            : in  sl;
      txClk            : in  sl;
      -- RX Clocking
      rxRst            : in  sl;
      rxRecClk         : out sl;        -- rxrecclk basically
      rxRecClkRst      : out sl;        -- Reset for recovered clock
      rxClk            : in  sl;  -- Run recClk through external MMCM and sent to this input
      rxMmcmRst        : out sl;
      rxMmcmLocked     : in  sl := '1';
      -- MGT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      gtCPllRefClk     : in  sl := '0';           -- Drives CPLL if used
      gtCPllLock       : out sl;
      gtQPllRefClk     : in  sl := '0';           -- Signals from QPLL if used
      gtQPllClk        : in  sl := '0';
      gtQPllLock       : in  sl := '0';
      gtQPllRefClkLost : in  sl := '0';
      gtQPllReset      : out sl;
      -- MGT loopback control
      loopback         : in  slv(2 downto 0);
      -- MGT Serial IO
      gtRxN            : in  sl;
      gtRxP            : in  sl;
      gtTxN            : out sl;
      gtTxP            : out sl);

end GLinkGtp7FixedLat;

architecture rtl of GLinkGtp7FixedLat is
   
   constant FIXED_ALIGN_COMMA_0_G : slv(19 downto 0) := x"FF003";  --FF0
   constant FIXED_ALIGN_COMMA_1_G : slv(19 downto 0) := x"FE003";  --FF1A
   constant FIXED_ALIGN_COMMA_2_G : slv(19 downto 0) := x"FF803";  --FF1B

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
         idle        => txIdle,
         control     => txControl,
         rawData     => txDataIn,
         encodedData => gtTxData);

   GLinkDecoder_Inst : entity work.GLinkDecoder
      generic map (
         RST_POLARITY_G => '0')  
      port map (
         clk          => rxClk,
         rst          => gtRxRstDone,
         gtRxData     => gtRxData,
         decodedData  => rxDataOut,
         isControl    => rxIsControl,
         isData       => rxIsData,
         isIdle       => rxIsIdle,
         flag         => rxFlag,
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
         RXOUT_DIV_G           => RXOUT_DIV_G,
         TXOUT_DIV_G           => TXOUT_DIV_G,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_G,
         PMA_RSV_G             => PMA_RSV_G,
         RX_OS_CFG_G           => RX_OS_CFG_G,
         RXCDR_CFG_G           => RXCDR_CFG_G,
         RXLPM_INCM_CFG_G      => RXLPM_INCM_CFG_G,
         RXLPM_IPCM_CFG_G      => RXLPM_IPCM_CFG_G,
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
         RXSLIDE_MODE_G        => "PMA",
         FIXED_COMMA_EN_G      => "0111",
         FIXED_ALIGN_COMMA_0_G => FIXED_ALIGN_COMMA_0_C,
         FIXED_ALIGN_COMMA_1_G => FIXED_ALIGN_COMMA_1_C,
         FIXED_ALIGN_COMMA_2_G => FIXED_ALIGN_COMMA_2_C,
         FIXED_ALIGN_COMMA_3_G => "XXXXXXXXXXXXXXXXXXXX")
      port map (
         stableClkIn      => stableClk,
         qPllRefClkIn     => gtQPllOutRefClk,
         qPllClkIn        => gtQPllOutClk,
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
