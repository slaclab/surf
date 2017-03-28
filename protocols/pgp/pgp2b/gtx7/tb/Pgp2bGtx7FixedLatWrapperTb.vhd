-------------------------------------------------------------------------------
-- File       : Pgp2bGtx7FixedLatWrapperTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-31
-- Last update: 2016-10-31
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for Pgp2bGtx7FixedLatWrapper
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
use work.AxiLitePkg.all;
use work.AxiStreamPkg.all;
use work.Gtx7CfgPkg.all;
use work.Pgp2bPkg.all;

----------------------------------------------------------------------------------------------------

entity Pgp2bGtx7FixedLatWrapperTb is

end entity Pgp2bGtx7FixedLatWrapperTb;

----------------------------------------------------------------------------------------------------

architecture tb of Pgp2bGtx7FixedLatWrapperTb is

   -- component generics
   constant TPD_G                   : time                 := 1 ns;
   constant SIM_GTRESET_SPEEDUP_G   : string               := "TRUE";
   constant SIM_VERSION_G           : string               := "4.0";
   constant SIMULATION_G            : boolean              := true;
   constant VC_INTERLEAVE_G         : integer              := 0;
   constant PAYLOAD_CNT_TOP_G       : integer              := 7;
   constant NUM_VC_EN_G             : integer range 1 to 4 := 4;
   constant AXI_ERROR_RESP_G        : slv(1 downto 0)      := AXI_RESP_DECERR_C;
   constant TX_ENABLE_G             : boolean              := true;
   constant RX_ENABLE_G             : boolean              := true;
   constant TX_CM_EN_G              : boolean              := false;
   constant TX_CM_TYPE_G            : string               := "MMCM";
   constant TX_CM_CLKIN_PERIOD_G    : real                 := 8.000;
   constant TX_CM_DIVCLK_DIVIDE_G   : natural              := 8;
   constant TX_CM_CLKFBOUT_MULT_F_G : real                 := 8.000;
   constant TX_CM_CLKOUT_DIVIDE_F_G : real                 := 8.000;
   constant RX_CM_EN_G              : boolean              := false;
   constant RX_CM_TYPE_G            : string               := "MMCM";
   constant RX_CM_CLKIN_PERIOD_G    : real                 := 8.000;
   constant RX_CM_DIVCLK_DIVIDE_G   : natural              := 8;
   constant RX_CM_CLKFBOUT_MULT_F_G : real                 := 8.000;
   constant RX_CM_CLKOUT_DIVIDE_F_G : real                 := 8.000;
   constant RX_OS_CFG_G             : bit_vector           := "0000010000000";
   constant RXCDR_CFG_G             : bit_vector           := x"03000023ff40200020";
   constant RXDFEXYDEN_G            : sl                   := '0';
   constant RX_DFE_KL_CFG2_G        : bit_vector           := x"3008E56A";
   constant STABLE_CLK_SRC_G        : string               := "gtClk0";
   constant TX_REFCLK_SRC_G         : string               := "gtClk0";
   constant RX_REFCLK_SRC_G         : string               := "gtClk1";
   constant CPLL_CFG_G              : Gtx7CPllCfgType      := getGtx7CPllCfg(250.0E6, 3.125E9);
   constant QPLL_CFG_G              : Gtx7QPllCfgType      := getGtx7QPllCfg(156.25e6, 3.125e9);
   constant TX_PLL_G                : string               := "QPLL";
   constant RX_PLL_G                : string               := "CPLL";

   -- component ports
   signal stableClkIn  : sl := '0';     -- [in]
   signal extRst       : sl;            -- [in]
   signal txPllLock    : sl;            -- [out]
   signal rxPllLock    : sl;            -- [out]
   signal pgpTxClkOut  : sl;            -- [out]
   signal pgpRxClkOut  : sl;            -- [out]
   signal pgpRxRstOut  : sl;            -- [out]
   signal stableClkOut : sl;            -- [out]

   signal pgpRxIn          : Pgp2bRxInType                    := PGP2B_RX_IN_INIT_C;  -- [in]
   signal pgpRxOut         : Pgp2bRxOutType;                                          -- [out]
   signal pgpTxIn          : Pgp2bTxInType                    := PGP2B_TX_IN_INIT_C;  -- [in]
   signal pgpTxOut         : Pgp2bTxOutType;                                          -- [out]
   signal pgpTxMasters     : AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);  -- [in]
   signal pgpTxSlaves      : AxiStreamSlaveArray(3 downto 0);                         -- [out]
   signal pgpRxMasters     : AxiStreamMasterArray(3 downto 0);                        -- [out]
   signal pgpRxMasterMuxed : AxiStreamMasterType;                                     -- [out]
   signal pgpRxCtrl        : AxiStreamCtrlArray(3 downto 0)   := (others => AXI_STREAM_CTRL_UNUSED_C);  -- [in]

   signal gtgClk          : sl                     := '0';                           -- [in]
   signal gtClk0P         : sl                     := '0';                           -- [in]
   signal gtClk0N         : sl                     := '0';                           -- [in]
   signal gtClk1P         : sl                     := '0';                           -- [in]
   signal gtClk1N         : sl                     := '0';                           -- [in]
   signal gtTxP           : sl;                                                      -- [out]
   signal gtTxN           : sl;                                                      -- [out]
   signal gtRxP           : sl;                                                      -- [in]
   signal gtRxN           : sl;                                                      -- [in]
   signal txPreCursor     : slv(4 downto 0)        := (others => '0');               -- [in]
   signal txPostCursor    : slv(4 downto 0)        := (others => '0');               -- [in]
   signal txDiffCtrl      : slv(3 downto 0)        := "1000";                        -- [in]
   signal axilClk         : sl                     := '0';                           -- [in]
   signal axilRst         : sl                     := '0';                           -- [in]
   signal axilReadMaster  : AxiLiteReadMasterType  := AXI_LITE_READ_MASTER_INIT_C;   -- [in]
   signal axilReadSlave   : AxiLiteReadSlaveType;                                    -- [out]
   signal axilWriteMaster : AxiLiteWriteMasterType := AXI_LITE_WRITE_MASTER_INIT_C;  -- [in]
   signal axilWriteSlave  : AxiLiteWriteSlaveType;                                   -- [out]

begin

   gtRxP <= gtTxP;
   gtRxN <= gtTxN;

   -- component instantiation
   U_Pgp2bGtx7FixedLatWrapper : entity work.Pgp2bGtx7FixedLatWrapper
      generic map (
         TPD_G                   => TPD_G,
         SIM_GTRESET_SPEEDUP_G   => SIM_GTRESET_SPEEDUP_G,
         SIM_VERSION_G           => SIM_VERSION_G,
         SIMULATION_G            => SIMULATION_G,
         VC_INTERLEAVE_G         => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G       => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G             => NUM_VC_EN_G,
         AXI_ERROR_RESP_G        => AXI_ERROR_RESP_G,
         TX_ENABLE_G             => TX_ENABLE_G,
         RX_ENABLE_G             => RX_ENABLE_G,
         TX_CM_EN_G              => TX_CM_EN_G,
         TX_CM_TYPE_G            => TX_CM_TYPE_G,
         TX_CM_CLKIN_PERIOD_G    => TX_CM_CLKIN_PERIOD_G,
         TX_CM_DIVCLK_DIVIDE_G   => TX_CM_DIVCLK_DIVIDE_G,
         TX_CM_CLKFBOUT_MULT_F_G => TX_CM_CLKFBOUT_MULT_F_G,
         TX_CM_CLKOUT_DIVIDE_F_G => TX_CM_CLKOUT_DIVIDE_F_G,
         RX_CM_EN_G              => RX_CM_EN_G,
         RX_CM_TYPE_G            => RX_CM_TYPE_G,
         RX_CM_CLKIN_PERIOD_G    => RX_CM_CLKIN_PERIOD_G,
         RX_CM_DIVCLK_DIVIDE_G   => RX_CM_DIVCLK_DIVIDE_G,
         RX_CM_CLKFBOUT_MULT_F_G => RX_CM_CLKFBOUT_MULT_F_G,
         RX_CM_CLKOUT_DIVIDE_F_G => RX_CM_CLKOUT_DIVIDE_F_G,
         RX_OS_CFG_G             => RX_OS_CFG_G,
         RXCDR_CFG_G             => RXCDR_CFG_G,
         RXDFEXYDEN_G            => RXDFEXYDEN_G,
         RX_DFE_KL_CFG2_G        => RX_DFE_KL_CFG2_G,
         STABLE_CLK_SRC_G        => STABLE_CLK_SRC_G,
         TX_REFCLK_SRC_G         => TX_REFCLK_SRC_G,
         RX_REFCLK_SRC_G         => RX_REFCLK_SRC_G,
         CPLL_CFG_G              => CPLL_CFG_G,
         QPLL_CFG_G              => QPLL_CFG_G,
         TX_PLL_G                => TX_PLL_G,
         RX_PLL_G                => RX_PLL_G)
      port map (
         stableClkIn      => stableClkIn,       -- [in]
         extRst           => extRst,            -- [in]
         txPllLock        => txPllLock,         -- [out]
         rxPllLock        => rxPllLock,         -- [out]
         pgpTxClkOut      => pgpTxClkOut,       -- [out]
         pgpRxClkOut      => pgpRxClkOut,       -- [out]
         pgpRxRstOut      => pgpRxRstOut,       -- [out]
         stableClkOut     => stableClkOut,      -- [out]
         pgpRxIn          => pgpRxIn,           -- [in]
         pgpRxOut         => pgpRxOut,          -- [out]
         pgpTxIn          => pgpTxIn,           -- [in]
         pgpTxOut         => pgpTxOut,          -- [out]
         pgpTxMasters     => pgpTxMasters,      -- [in]
         pgpTxSlaves      => pgpTxSlaves,       -- [out]
         pgpRxMasters     => pgpRxMasters,      -- [out]
         pgpRxMasterMuxed => pgpRxMasterMuxed,  -- [out]
         pgpRxCtrl        => pgpRxCtrl,         -- [in]
         gtgClk           => gtgClk,            -- [in]
         gtClk0P          => gtClk0P,           -- [in]
         gtClk0N          => gtClk0N,           -- [in]
         gtClk1P          => gtClk1P,           -- [in]
         gtClk1N          => gtClk1N,           -- [in]
         gtTxP            => gtTxP,             -- [out]
         gtTxN            => gtTxN,             -- [out]
         gtRxP            => gtRxP,             -- [in]
         gtRxN            => gtRxN,             -- [in]
         txPreCursor      => txPreCursor,       -- [in]
         txPostCursor     => txPostCursor,      -- [in]
         txDiffCtrl       => txDiffCtrl,        -- [in]
         axilClk          => axilClk,           -- [in]
         axilRst          => axilRst,           -- [in]
         axilReadMaster   => axilReadMaster,    -- [in]
         axilReadSlave    => axilReadSlave,     -- [out]
         axilWriteMaster  => axilWriteMaster,   -- [in]
         axilWriteSlave   => axilWriteSlave);   -- [out]


   U_ClkRst_GT_CLK0 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 6.4 ns,
         CLK_DELAY_G       => 0 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => gtClk0P,
         clkN => gtClk0N,
         rst  => extRst,
         rstL => open);

   U_ClkRst_GT_CLK1 : entity work.ClkRst
      generic map (
         CLK_PERIOD_G      => 4 ns,
         CLK_DELAY_G       => 1.11231 ns,
         RST_START_DELAY_G => 0 ns,
         RST_HOLD_TIME_G   => 5 us,
         SYNC_RESET_G      => true)
      port map (
         clkP => gtClk1P,
         clkN => gtClk1N,
         rst  => open,
         rstL => open);

end architecture tb;

----------------------------------------------------------------------------------------------------
