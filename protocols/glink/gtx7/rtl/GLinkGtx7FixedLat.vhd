-------------------------------------------------------------------------------
-- File       : GLinkGtx7FixedLat.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-30
-- Last update: 2015-02-23
-------------------------------------------------------------------------------
-- Description: G-Link wrapper for GTX7 Fixed Latency transceiver
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

entity GLinkGtx7FixedLat is
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
      -- CPLL Settings
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      CPLL_FBDIV_G          : integer    := 4;
      CPLL_FBDIV_45_G       : integer    := 5;
      CPLL_REFCLK_DIV_G     : integer    := 1;
      -- MGT Settings
      RXOUT_DIV_G           : integer    := 2;
      TXOUT_DIV_G           : integer    := 2;
      RX_CLK25_DIV_G        : integer    := 5;                      -- Set by wizard
      TX_CLK25_DIV_G        : integer    := 5;                      -- Set by wizard
      RX_OS_CFG_G           : bit_vector := "0000010000000";        -- Set by wizard
      RXCDR_CFG_G           : bit_vector := x"03000023ff40200020";  -- Set by wizard      
      -- RX Equalizer Attributes
      RX_DFE_KL_CFG2_G      : bit_vector := x"3008E56A";            -- Set by wizard
      RX_CM_TRIM_G          : bit_vector := "010";
      RX_DFE_LPM_CFG_G      : bit_vector := x"0954";
      RXDFELFOVRDEN_G       : sl         := '1';
      RXDFEXYDEN_G          : sl         := '1';                     -- This should always be 1      
      -- Configure PLL sources
      TX_PLL_G              : string     := "QPLL";
      RX_PLL_G              : string     := "CPLL");
   port (
      -- G-Link TX Interface (gLinkTxClk Domain)
      gLinkTx          : in  GLinkTxType;
      txReady          : out sl;
      gLinkTxClk       : in  sl;
      gLinkTxClkEn     : in  sl := '1';
      gLinkTxRst       : in  sl := '0';
      -- G-Link TX Interface (gLinkClk Domain)
      gLinkRx          : out GLinkRxType;
      rxReady          : out sl;
      gLinkRxClk       : in  sl;
      gLinkRxClkEn     : in  sl := '1';
      gLinkRxRst       : in  sl := '0';
      -- MGT Clocking
      gLinkTxRefClk    : in  sl;                                    -- G-Link TX clock reference
      stableClk        : in  sl;
      gtCPllRefClk     : in  sl := '0';
      gtCPllLock       : out sl;
      gtQPllRefClk     : in  sl := '0';
      gtQPllClk        : in  sl := '0';
      gtQPllLock       : in  sl := '0';
      gtQPllRefClkLost : in  sl := '0';
      gtQPllReset      : out sl;
      -- Misc. MGT control
      lpmMode          : in  sl := '1';
      loopback         : in  slv(2 downto 0);
      txPowerDown      : in  sl;
      rxPowerDown      : in  sl;
      rxClkDebug       : out sl;                                    -- debug only
      -- MGT Serial IO
      gtTxP            : out sl;
      gtTxN            : out sl;
      gtRxP            : in  sl;
      gtRxN            : in  sl);

end GLinkGtx7FixedLat;

architecture rtl of GLinkGtx7FixedLat is
   
   constant FIXED_ALIGN_COMMA_0_C : slv(19 downto 0) := bitReverse((GLINK_VALID_IDLE_WORDS_C(0) & GLINK_CONTROL_WORD_C));  -- FF0
   constant FIXED_ALIGN_COMMA_1_C : slv(19 downto 0) := bitReverse((GLINK_VALID_IDLE_WORDS_C(1) & GLINK_CONTROL_WORD_C));  -- FF1A
   constant FIXED_ALIGN_COMMA_2_C : slv(19 downto 0) := bitReverse((GLINK_VALID_IDLE_WORDS_C(2) & GLINK_CONTROL_WORD_C));  -- FF1B

   signal txFifoValid,
      rxFifoValid,
      rxRecClk,
      rxClk,
      rxRst,
      txClk,
      txUserReset,
      rxUserReset,
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

   rxClkDebug <= rxClk;

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

   rxUserReset <= gLinkTx.linkRst or gLinkRxRst;
   txUserReset <= gLinkTx.linkRst or gLinkTxRst;

   -- GTX 7 Core in Fixed Latency mode
   Gtx7Core_Inst : entity work.GLinkGtx7Core
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
         -- Configure TX
         TX_EXT_DATA_WIDTH_G   => 20,
         TX_INT_DATA_WIDTH_G   => 20,
         TX_8B10B_EN_G         => false,
         TX_BUF_EN_G           => false,
         TX_OUTCLK_SRC_G       => "PLLREFCLK",
         TX_DLY_BYPASS_G       => '0',
         TX_PHASE_ALIGN_G      => "MANUAL",
         TX_BUF_ADDR_MODE_G    => "FAST",
         -- Configure RX
         RX_EXT_DATA_WIDTH_G   => 20,
         RX_INT_DATA_WIDTH_G   => 20,
         RX_8B10B_EN_G         => false,
         RX_BUF_EN_G           => false,
         RX_OUTCLK_SRC_G       => "OUTCLKPMA",
         RX_USRCLK_SRC_G       => "RXOUTCLK",
         RX_DLY_BYPASS_G       => '1',
         RX_DDIEN_G            => '0',
         RX_ALIGN_MODE_G       => "FIXED_LAT",
         RX_OS_CFG_G           => RX_OS_CFG_G,
         RXCDR_CFG_G           => RXCDR_CFG_G,
         RXSLIDE_MODE_G        => "PMA",
         -- RX Equalizer Attributes
         RX_DFE_KL_CFG2_G      => RX_DFE_KL_CFG2_G,
         RX_CM_TRIM_G          => RX_CM_TRIM_G,
         RX_DFE_LPM_CFG_G      => RX_DFE_LPM_CFG_G,
         RXDFELFOVRDEN_G       => RXDFELFOVRDEN_G,
         RXDFEXYDEN_G          => RXDFEXYDEN_G,
         -- Fixed Latency comma alignment (If RX_ALIGN_MODE_G = "FIXED_LAT")
         FIXED_COMMA_EN_G      => "0111",
         FIXED_ALIGN_COMMA_0_G => FIXED_ALIGN_COMMA_0_C,
         FIXED_ALIGN_COMMA_1_G => FIXED_ALIGN_COMMA_1_C,
         FIXED_ALIGN_COMMA_2_G => FIXED_ALIGN_COMMA_2_C,
         FIXED_ALIGN_COMMA_3_G => "XXXXXXXXXXXXXXXXXXXX")
      port map (
         lpmMode          => lpmMode,
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
         gtRxRefClkBufg   => gLinkTxRefClk,
         rxOutClkOut      => rxRecClk,
         rxUsrClkIn       => rxClk,
         rxUsrClk2In      => rxClk,
         rxUserRdyOut     => open,
         rxMmcmResetOut   => open,
         rxMmcmLockedIn   => '1',
         rxUserResetIn    => rxUserReset,      -- Sync'd in Gtx7RxRst.vhd
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
         txUserResetIn    => txUserReset,
         txResetDoneOut   => gtTxRstDone,
         txDataIn         => gtTxDataReversed,
         txCharIsKIn      => (others => '0'),  -- Not using gt rx 8b10b
         txBufStatusOut   => open,
         txPowerDown(0)   => txPowerDown,
         txPowerDown(1)   => txPowerDown,
         rxPowerDown(0)   => rxPowerDown,
         rxPowerDown(1)   => rxPowerDown,
         loopbackIn       => loopback);         
end rtl;
