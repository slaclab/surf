-------------------------------------------------------------------------------
-- Title      : PGPv2b: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Gtp7 Variable Latency Wrapper
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


library surf;
use surf.StdRtlPkg.all;
use surf.Pgp2bPkg.all;
use surf.AxiStreamPkg.all;
use surf.AxiLitePkg.all;

entity Pgp2bGtp7VarLat is
   generic (
      TPD_G                 : time                 := 1 ns;
      COMMON_CLK_G          : boolean              := false;-- set true if (stableClk = axilClk)
      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string               := "FALSE";
      SIM_VERSION_G         : string               := "2.0";
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
      DYNAMIC_QPLL_G        : boolean              := false;
      TX_PLL_G              : string               := "PLL0";
      RX_PLL_G              : string               := "PLL1";
      -- Configure Buffer usage
      TX_BUF_EN_G           : boolean              := true;
      TX_OUTCLK_SRC_G       : string               := "OUTCLKPMA";
      TX_DLY_BYPASS_G       : sl                   := '1';
      TX_PHASE_ALIGN_G      : string               := "NONE";
      TX_BUF_ADDR_MODE_G    : string               := "FULL";
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      VC_INTERLEAVE_G       : integer              := 0;      -- No interleave Frames
      PAYLOAD_CNT_TOP_G     : integer              := 7;      -- Top bit for payload counter
      NUM_VC_EN_G           : integer range 1 to 4 := 4;
      TX_POLARITY_G         : sl                   := '0';
      RX_POLARITY_G         : sl                   := '0';
      TX_ENABLE_G           : boolean              := true;   -- Enable TX direction
      RX_ENABLE_G           : boolean              := true);  -- Enable RX direction
   port (
      -- GT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      qPllRxSelect     : in  slv(1 downto 0) := "00";
      qPllTxSelect     : in  slv(1 downto 0) := "00";
      gtQPllOutRefClk  : in  slv(1 downto 0);
      gtQPllOutClk     : in  slv(1 downto 0);
      gtQPllLock       : in  slv(1 downto 0);
      gtQPllRefClkLost : in  slv(1 downto 0);
      gtQPllReset      : out slv(1 downto 0);
      -- Gt Serial IO
      gtTxP            : out sl;        -- GT Serial Transmit Positive
      gtTxN            : out sl;        -- GT Serial Transmit Negative
      gtRxP            : in  sl;        -- GT Serial Receive Positive
      gtRxN            : in  sl;        -- GT Serial Receive Negative
      -- Tx Clocking
      pgpTxReset       : in  sl;
      pgpTxRecClk      : out sl;        -- recovered clock
      pgpTxClk         : in  sl;
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
      drpOverride      : in  sl                               := '0';
      -- AXI-Lite Interface
      axilClk          : in  sl                               := '0';
      axilRst          : in  sl                               := '0';
      axilReadMaster   : in  AxiLiteReadMasterType            := AXI_LITE_READ_MASTER_INIT_C;
      axilReadSlave    : out AxiLiteReadSlaveType;
      axilWriteMaster  : in  AxiLiteWriteMasterType           := AXI_LITE_WRITE_MASTER_INIT_C;
      axilWriteSlave   : out AxiLiteWriteSlaveType);
end Pgp2bGtp7VarLat;

architecture mapping of Pgp2bGtp7VarLat is

begin

   MuliLane_Inst : entity surf.Pgp2bGtp7MultiLane
      generic map (
         TPD_G                 => TPD_G,
         COMMON_CLK_G          => COMMON_CLK_G,
         -- SIM Generics
         SIM_GTRESET_SPEEDUP_G => SIM_GTRESET_SPEEDUP_G,
         SIM_VERSION_G         => SIM_VERSION_G,
         STABLE_CLOCK_PERIOD_G => STABLE_CLOCK_PERIOD_G,
         -- Configure PLL
         RXOUT_DIV_G           => RXOUT_DIV_G,
         TXOUT_DIV_G           => TXOUT_DIV_G,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_G,
         PMA_RSV_G             => PMA_RSV_G,
         RX_OS_CFG_G           => RX_OS_CFG_G,
         RXCDR_CFG_G           => RXCDR_CFG_G,
         RXLPM_INCM_CFG_G      => RXLPM_INCM_CFG_G,
         RXLPM_IPCM_CFG_G      => RXLPM_IPCM_CFG_G,
         DYNAMIC_QPLL_G        => DYNAMIC_QPLL_G,
         TX_PLL_G              => TX_PLL_G,
         RX_PLL_G              => RX_PLL_G,
         -- Configure Buffer usage
         TX_BUF_EN_G           => TX_BUF_EN_G,
         TX_OUTCLK_SRC_G       => TX_OUTCLK_SRC_G,
         TX_DLY_BYPASS_G       => TX_DLY_BYPASS_G,
         TX_PHASE_ALIGN_G      => TX_PHASE_ALIGN_G,
         TX_BUF_ADDR_MODE_G    => TX_BUF_ADDR_MODE_G,
         -- PGP Settings
         VC_INTERLEAVE_G       => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G     => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G           => NUM_VC_EN_G,
         TX_POLARITY_G         => TX_POLARITY_G,
         RX_POLARITY_G         => RX_POLARITY_G,
         TX_ENABLE_G           => TX_ENABLE_G,
         RX_ENABLE_G           => RX_ENABLE_G)
      port map (
         -- GT Clocking
         stableClk           => stableClk,
         qPllRxSelect        => qPllRxSelect,
         qPllTxSelect        => qPllTxSelect,
         gtQPllOutRefClk     => gtQPllOutRefClk,
         gtQPllOutClk        => gtQPllOutClk,
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
         drpOverride         => drpOverride,
         -- AXI-Lite Interface
         axilClk             => axilClk,
         axilRst             => axilRst,
         axilReadMasters(0)  => axilReadMaster,
         axilReadSlaves(0)   => axilReadSlave,
         axilWriteMasters(0) => axilWriteMaster,
         axilWriteSlaves(0)  => axilWriteSlave);

end mapping;
