-------------------------------------------------------------------------------
-- File       : Pgp2bGtx7VarLat.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-01-14
-- Last update: 2016-08-24
-------------------------------------------------------------------------------
-- Description: Gtx7 Variable Latency Wrapper
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
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;
use work.AxiLitePkg.all;

entity Pgp2bGtx7VarLat is
   generic (
      TPD_G                 : time       := 1 ns;
      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "4.0";
      STABLE_CLOCK_PERIOD_G : real       := 4.0E-9;  --units of seconds (default to longest timeout)
      -- CPLL Settings
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      CPLL_FBDIV_G          : integer    := 4;
      CPLL_FBDIV_45_G       : integer    := 5;
      CPLL_REFCLK_DIV_G     : integer    := 1;
      RXOUT_DIV_G           : integer    := 2;
      TXOUT_DIV_G           : integer    := 2;
      RX_CLK25_DIV_G        : integer    := 7;
      TX_CLK25_DIV_G        : integer    := 7;

      PMA_RSV_G    : bit_vector := x"00018480";
      RX_OS_CFG_G  : bit_vector := "0000010000000";        -- Set by wizard
      RXCDR_CFG_G  : bit_vector := x"03000023ff40200020";  -- Set by wizard
      RXDFEXYDEN_G : sl         := '0';                    -- Set by wizard

      -- RX Equalizer Attributes
      RX_DFE_KL_CFG2_G : bit_vector := x"3010D90C";  -- Set by wizard
      -- Configure PLL sources
      TX_PLL_G         : string     := "QPLL";
      RX_PLL_G         : string     := "CPLL";

      -- Configure Buffer usage
      TX_BUF_EN_G        : boolean := true;
      TX_OUTCLK_SRC_G    : string  := "OUTCLKPMA";
      TX_DLY_BYPASS_G    : sl      := '1';
      TX_PHASE_ALIGN_G   : string  := "NONE";
      TX_BUF_ADDR_MODE_G : string  := "FULL";

      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      VC_INTERLEAVE_G   : integer              := 0;  -- No interleave Frames
      PAYLOAD_CNT_TOP_G : integer              := 7;  -- Top bit for payload counter
      NUM_VC_EN_G       : integer range 1 to 4 := 4;
      AXI_ERROR_RESP_G  : slv(1 downto 0)      := AXI_RESP_DECERR_C;
      TX_ENABLE_G       : boolean              := true;                -- Enable TX direction
      RX_ENABLE_G       : boolean              := true);               -- Enable RX direction
   port (
      -- GT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      gtCPllRefClk     : in  sl                               := '0';  -- Drives CPLL if used
      gtCPllLock       : out sl;
      gtQPllRefClk     : in  sl                               := '0';  -- Signals from QPLL if used
      gtQPllClk        : in  sl                               := '0';
      gtQPllLock       : in  sl                               := '1';
      gtQPllRefClkLost : in  sl                               := '0';
      gtQPllReset      : out sl;
      -- Gt Serial IO
      gtTxP            : out sl;        -- GT Serial Transmit Positive
      gtTxN            : out sl;        -- GT Serial Transmit Negative
      gtRxP            : in  sl;        -- GT Serial Receive Positive
      gtRxN            : in  sl;        -- GT Serial Receive Negative
      -- Tx Clocking
      pgpTxReset       : in  sl;
      pgpTxClk         : in  sl;
      pgpTxRecClk      : out sl;        -- recovered clock
      pgpTxMmcmReset   : out sl;
      pgpTxMmcmLocked  : in  sl                               := '1';
      -- Rx clocking
      pgpRxReset       : in  sl;
      pgpRxRecClk      : out sl;        -- recovered clock
      pgpRxClk         : in  sl;
      pgpRxMmcmReset   : out sl;
      pgpRxMmcmLocked  : in  sl                               := '1';
      -- Non VC Rx Signals
      pgpRxIn          : in  Pgp2bRxInType;
      pgpRxOut         : out Pgp2bRxOutType;
      -- Non VC Tx Signals
      pgpTxIn          : in  Pgp2bTxInType;
      pgpTxOut         : out Pgp2bTxOutType;
      -- Frame Transmit Interface - Array of 4 VCs
      pgpTxMasters     : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      pgpTxSlaves      : out AxiStreamSlaveArray(3 downto 0);
      -- Frame Receive Interface - Array of 4 VCs
      pgpRxMasters     : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed : out AxiStreamMasterType;
      pgpRxCtrl        : in  AxiStreamCtrlArray(3 downto 0);
      -- Debug Interface 
      txPreCursor      : in  slv(4 downto 0)                  := (others => '0');
      txPostCursor     : in  slv(4 downto 0)                  := (others => '0');
      txDiffCtrl       : in  slv(3 downto 0)                  := "1000";
      -- AXI-Lite Interface 
      axilClk          : in  sl                               := '0';
      axilRst          : in  sl                               := '0';
      axilReadMaster   : in  AxiLiteReadMasterType            := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType           := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave   : out AxiLiteWriteSlaveType);             
end Pgp2bGtx7VarLat;

architecture mapping of Pgp2bGtx7VarLat is

begin

   MuliLane_Inst : entity work.Pgp2bGtx7MultiLane
      generic map (
         -- Sim Generics
         TPD_G                 => TPD_G,
         SIM_GTRESET_SPEEDUP_G => SIM_GTRESET_SPEEDUP_G,
         SIM_VERSION_G         => SIM_VERSION_G,
         STABLE_CLOCK_PERIOD_G => STABLE_CLOCK_PERIOD_G,
         -- CPLL Settings
         CPLL_REFCLK_SEL_G     => CPLL_REFCLK_SEL_G,
         CPLL_FBDIV_G          => CPLL_FBDIV_G,
         CPLL_FBDIV_45_G       => CPLL_FBDIV_45_G,
         CPLL_REFCLK_DIV_G     => CPLL_REFCLK_DIV_G,
         RXOUT_DIV_G           => RXOUT_DIV_G,
         TXOUT_DIV_G           => TXOUT_DIV_G,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_G,
         PMA_RSV_G             => PMA_RSV_G,
         RX_OS_CFG_G           => RX_OS_CFG_G,
         RXCDR_CFG_G           => RXCDR_CFG_G,
         RXDFEXYDEN_G          => RXDFEXYDEN_G,
         -- RX Equalizer Attributes
         RX_DFE_KL_CFG2_G      => RX_DFE_KL_CFG2_G,
         -- Configure PLL sources
         TX_PLL_G              => TX_PLL_G,
         RX_PLL_G              => RX_PLL_G,
         -- Configure Buffer usage
         TX_BUF_EN_G           => TX_BUF_EN_G,
         TX_OUTCLK_SRC_G       => TX_OUTCLK_SRC_G,
         TX_DLY_BYPASS_G       => TX_DLY_BYPASS_G,
         TX_PHASE_ALIGN_G      => TX_PHASE_ALIGN_G,
         TX_BUF_ADDR_MODE_G    => TX_BUF_ADDR_MODE_G,
         -- Configure Number of Lanes
         LANE_CNT_G            => 1,
         -- PGP Settings
         VC_INTERLEAVE_G       => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G     => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G           => NUM_VC_EN_G,
         AXI_ERROR_RESP_G      => AXI_ERROR_RESP_G,
         TX_ENABLE_G           => TX_ENABLE_G,
         RX_ENABLE_G           => RX_ENABLE_G)  
      port map (
         -- GT Clocking
         stableClk           => stableClk,
         gtCPllRefClk        => gtCPllRefClk,
         gtCPllLock          => gtCPllLock,
         gtQPllRefClk        => gtQPllRefClk,
         gtQPllClk           => gtQPllClk,
         gtQPllLock          => gtQPllLock,
         gtQPllRefClkLost    => gtQPllRefClkLost,
         gtQPllReset         => gtQPllReset,
         -- Gt Serial IO
         gtTxP(0)            => gtTxP,
         gtTxN(0)            => gtTxN,
         gtRxP(0)            => gtRxP,
         gtRxN(0)            => gtRxN,
         -- Tx Clocking
         pgpTxReset          => pgpTxReset,
         pgpTxRecClk         => pgpTxRecClk,
         pgpTxClk            => pgpTxClk,
         pgpTxMmcmReset      => pgpTxMmcmReset,
         pgpTxMmcmLocked     => pgpTxMmcmLocked,
         -- Rx clocking
         pgpRxReset          => pgpRxReset,
         pgpRxRecClk         => pgpRxRecClk,
         pgpRxClk            => pgpRxClk,
         pgpRxMmcmReset      => pgpRxMmcmReset,
         pgpRxMmcmLocked     => pgpRxMmcmLocked,
         -- Non VC Rx Signals
         pgpRxIn             => pgpRxIn,
         pgpRxOut            => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn             => pgpTxIn,
         pgpTxOut            => pgpTxOut,
         -- Frame Transmit Interface - Array of 4 VCs
         pgpTxMasters        => pgpTxMasters,
         pgpTxSlaves         => pgpTxSlaves,
         -- Frame Receive Interface - Array of 4 VCs
         pgpRxMasters        => pgpRxMasters,
         pgpRxMasterMuxed    => pgpRxMasterMuxed,
         pgpRxCtrl           => pgpRxCtrl,
         -- Debug Interface 
         txPreCursor         => txPreCursor,
         txPostCursor        => txPostCursor,
         txDiffCtrl          => txDiffCtrl,
         -- AXI-Lite Interface 
         axilClk             => axilClk,
         axilRst             => axilRst,
         axilReadMasters(0)  => axilReadMaster,
         axilReadSlaves(0)   => axilReadSlave,
         axilWriteMasters(0) => axilWriteMaster,
         axilWriteSlaves(0)  => axilWriteSlave);                 

end mapping;
