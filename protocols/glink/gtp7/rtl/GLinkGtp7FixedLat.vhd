-------------------------------------------------------------------------------
-- File       : GLinkGtp7FixedLat.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-30
-- Last update: 2014-06-04
-------------------------------------------------------------------------------
-- Description: G-Link wrapper for GTP7 transceiver
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
use work.GlinkPkg.all;

entity GLinkGtp7FixedLat is
   generic (
      -- GLink Settings
      FLAGSEL_G             : boolean    := false;
      SYNTH_TX_G            : boolean    := true;
      SYNTH_RX_G            : boolean    := true;
      -- Simulation Generics
      TPD_G                 : time       := 1 ns;
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "4.0";
      SIMULATION_G          : boolean    := false;
      -- MGT Settings
      RXOUT_DIV_G           : integer    := 2;
      TXOUT_DIV_G           : integer    := 2;
      RX_CLK25_DIV_G        : integer    := 5;                         -- Set by wizard
      TX_CLK25_DIV_G        : integer    := 5;                         -- Set by wizard
      PMA_RSV_G             : bit_vector := x"00000333";               -- Set by wizard
      RX_OS_CFG_G           : bit_vector := "0001111110000";           -- Set by wizard
      RXCDR_CFG_G           : bit_vector := x"0000107FE206001041010";  -- Set by wizard
      RXLPM_INCM_CFG_G      : bit        := '1';                       -- Set by wizard
      RXLPM_IPCM_CFG_G      : bit        := '0';                       -- Set by wizard         
      -- Configure PLL sources
      TX_PLL_G              : string     := "PLL0";
      RX_PLL_G              : string     := "PLL1");
   port (
      -- G-Link TX Interface (gLinkTxClk Domain)
      gLinkTx          : in  GLinkTxType;
      txReady          : out sl;
      gLinkTxClk       : in  sl;
      gLinkTxClkEn     : in  sl := '1';
      -- G-Link TX Interface (gLinkClk Domain)
      gLinkRx          : out GLinkRxType;
      rxReady          : out sl;
      gLinkRxClk       : in  sl;
      gLinkRxClkEn     : in  sl := '1';
      -- MGT Clocking
      gLinkTxRefClk    : in  sl;                                       -- G-Link TX clock reference
      stableClk        : in  sl;
      gtCPllRefClk     : in  sl := '0';
      gtCPllLock       : out sl;
      gtQPllRefClk     : in  sl := '0';
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

end GLinkGtp7FixedLat;

architecture rtl of GLinkGtp7FixedLat is
   
   constant FIXED_ALIGN_COMMA_0_C : slv(19 downto 0) := bitReverse((GLINK_VALID_IDLE_WORDS_C(0) & GLINK_CONTROL_WORD_C));  -- FF0
   constant FIXED_ALIGN_COMMA_1_C : slv(19 downto 0) := bitReverse((GLINK_VALID_IDLE_WORDS_C(1) & GLINK_CONTROL_WORD_C));  -- FF1A
   constant FIXED_ALIGN_COMMA_2_C : slv(19 downto 0) := bitReverse((GLINK_VALID_IDLE_WORDS_C(2) & GLINK_CONTROL_WORD_C));  -- FF1B

   signal txFifoValid,
      rxFifoValid,
      rxRecClk,
      rxClk,
      rxRst,
      txClk,
      gtTxRstDone,
      gtRxRstDone,
      gtTxRst,
      gtRxRst,
      dataValid : sl := '0';
   signal txFifoDout,
      gtTxData,
      gtRxData,
      gtTxDataReversed,
      gtRxDataReversed : slv(19 downto 0) := (others => '0');
   signal rxFifoDout  : slv(23 downto 0);
   signal gLinkTxSync : GLinkTxType;
   signal gLinkRxSync : GLinkRxType;

begin
   
   SYNTH_TX : if (SYNTH_TX_G = true) generate
      
      txClk <= gLinkTxRefClk;

      Synchronizer_0 : entity work.Synchronizer
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => gLinkTxClk,
            dataIn  => gtTxRstDone,
            dataOut => txReady);  

      SyncFifo_TX : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            INIT_G       => toSlv(GLINK_TX_UNUSED_C),
            DATA_WIDTH_G => 20)
         port map (
            --Write Ports (wr_clk domain)
            wr_clk => gLinkTxClk,
            wr_en  => gLinkTxClkEn,
            din    => toSlv(gLinkTx),
            --Read Ports (rd_clk domain)
            rd_clk => txClk,
            valid  => txFifoValid,
            dout   => txFifoDout); 

      gLinkTxSync <= toGLinkTx(txFifoDout) when(txFifoValid = '1') else GLINK_TX_UNUSED_C;

      gtTxRst <= not(gtTxRstDone) or gLinkTxSync.linkRst;

      GLinkEncoder_Inst : entity work.GLinkEncoder
         generic map (
            TPD_G          => TPD_G,
            FLAGSEL_G      => FLAGSEL_G,
            RST_POLARITY_G => '1')  
         port map (
            clk         => txClk,
            rst         => gtTxRst,
            gLinkTx     => gLinkTxSync,
            encodedData => gtTxData);      

   end generate;

   DISABLE_SYNTH_TX : if (SYNTH_TX_G = false) generate
      
      txClk       <= '0';
      txReady     <= '1';
      gLinkTxSync <= GLINK_TX_UNUSED_C;
      gtTxRst     <= '0';
      gtTxData    <= (GLINK_IDLE_WORD_FF0_C & GLINK_CONTROL_WORD_C);
      
   end generate;

   SYNTH_RX : if (SYNTH_RX_G = true) generate
      
      rxClk <= rxRecClk;

      Synchronizer_1 : entity work.Synchronizer
         generic map (
            TPD_G => TPD_G)
         port map (
            clk     => gLinkRxClk,
            dataIn  => gtRxRstDone,
            dataOut => rxReady); 

      SyncFifo_RX : entity work.SynchronizerFifo
         generic map (
            TPD_G        => TPD_G,
            INIT_G       => toSlv(GLINK_RX_INIT_C),
            DATA_WIDTH_G => 24)
         port map (
            -- Asynchronous Reset
            rst    => gtRxRst,
            --Write Ports (wr_clk domain)
            wr_clk => rxClk,
            wr_en  => gtRxRstDone,
            din    => toSlv(gLinkRxSync),
            --Read Ports (rd_clk domain)
            rd_clk => gLinkRxClk,
            rd_en  => gLinkRxClkEn,
            valid  => rxFifoValid,
            dout   => rxFifoDout); 

      gLinkRx <= toGLinkRx(rxFifoDout);

      rxRst   <= '0';
      gtRxRst <= not(gtRxRstDone) or rxRst;

      GLinkDecoder_Inst : entity work.GLinkDecoder
         generic map (
            TPD_G          => TPD_G,
            FLAGSEL_G      => FLAGSEL_G,
            RST_POLARITY_G => '1')  
         port map (
            clk           => rxClk,
            rst           => gtRxRst,
            gtRxData      => gtRxData,
            rxReady       => gtRxRstDone,
            txReady       => gtTxRstDone,
            gLinkRx       => gLinkRxSync,
            decoderErrorL => dataValid);   

   end generate;

   DISABLE_SYNTH_RX : if (SYNTH_RX_G = false) generate
      
      rxClk     <= '0';
      rxReady   <= '1';
      gLinkRx   <= GLINK_RX_INIT_C;
      rxRst     <= '0';
      gtRxRst   <= '0';
      dataValid <= '1';
      
   end generate;

   gtTxDataReversed <= bitReverse(gtTxData);
   gtRxData         <= bitReverse(gtRxDataReversed);

   -- GTP 7 Core in Fixed Latency mode
   Gtp7Core_Inst : entity work.Gtp7Core
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
         gtRxRefClkBufg   => gLinkTxRefClk,
         rxOutClkOut      => rxRecClk,
         rxUsrClkIn       => rxClk,
         rxUsrClk2In      => rxClk,
         rxUserRdyOut     => open,
         rxMmcmResetOut   => open,
         rxMmcmLockedIn   => '1',
         rxUserResetIn    => rxRst,
         rxResetDoneOut   => gtRxRstDone,
         rxDataValidIn    => dataValid,
         rxSlideIn        => '0',              -- Slide is controlled internally
         rxDataOut        => gtRxDataReversed,
         rxCharIsKOut     => open,             -- Not using gt rx 8b10b
         rxDecErrOut      => open,             -- Not using gt rx 8b10b
         rxDispErrOut     => open,             -- Not using gt rx 8b10b
         rxPolarityIn     => '0',
         rxBufStatusOut   => open,
         txOutClkOut      => open,
         txUsrClkIn       => txClk,
         txUsrClk2In      => txClk,
         txUserRdyOut     => open,             -- Not sure what to do with this
         txMmcmResetOut   => open,             -- No Tx MMCM in Fixed Latency mode
         txMmcmLockedIn   => '1',
         txUserResetIn    => gLinkTxSync.linkRst,
         txResetDoneOut   => gtTxRstDone,
         txDataIn         => gtTxDataReversed,
         txCharIsKIn      => (others => '0'),  -- Not using gt rx 8b10b
         txBufStatusOut   => open,
         loopbackIn       => loopback);
end rtl;
