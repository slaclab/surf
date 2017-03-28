-------------------------------------------------------------------------------
-- File       : Pgp2bGtx7VarLatWrapperTb.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2016-10-31
-- Last update: 2016-10-31
-------------------------------------------------------------------------------
-- Description: Simulation Testbed for Pgp2bGtx7VarLatWrapper
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

----------------------------------------------------------------------------------------------------

entity Pgp2bGtx7VarLatWrapperTb is

end entity Pgp2bGtx7VarLatWrapperTb;

----------------------------------------------------------------------------------------------------

architecture tb of Pgp2bGtx7VarLatWrapperTb is

   -- component generics
   constant TPD_G              : time                    := 1 ns;
   constant CLKIN_PERIOD_G     : real                    := 16.0;
   constant DIVCLK_DIVIDE_G    : natural range 1 to 106  := 2;
   constant CLKFBOUT_MULT_F_G  : real range 1.0 to 64.0  := 31.875;
   constant CLKOUT0_DIVIDE_F_G : real range 1.0 to 128.0 := 6.375;
   constant CPLL_REFCLK_SEL_G  : bit_vector              := "001";
   constant CPLL_FBDIV_G       : natural                 := 5;
   constant CPLL_FBDIV_45_G    : natural                 := 5;
   constant CPLL_REFCLK_DIV_G  : natural                 := 1;
   constant RXOUT_DIV_G        : natural                 := 2;
   constant TXOUT_DIV_G        : natural                 := 2;
   constant RX_CLK25_DIV_G     : natural                 := 5;
   constant TX_CLK25_DIV_G     : natural                 := 5;
   constant RX_OS_CFG_G        : bit_vector              := "0000010000000";
   constant RXCDR_CFG_G        : bit_vector              := x"03000023ff40200020";
   constant RXDFEXYDEN_G       : sl                      := '1';
   constant RX_DFE_KL_CFG2_G   : bit_vector              := x"301148AC";
   constant TX_BUF_EN_G        : boolean                 := true;
   constant TX_OUTCLK_SRC_G    : string                  := "OUTCLKPMA";
   constant TX_DLY_BYPASS_G    : sl                      := '1';
   constant TX_PHASE_ALIGN_G   : string                  := "NONE";
   constant VC_INTERLEAVE_G    : integer                 := 0;
   constant PAYLOAD_CNT_TOP_G  : integer                 := 7;
   constant NUM_VC_EN_G        : integer range 1 to 4    := 4;
   constant AXI_ERROR_RESP_G   : slv(1 downto 0)         := AXI_RESP_DECERR_C;
   constant TX_ENABLE_G        : boolean                 := true;
   constant RX_ENABLE_G        : boolean                 := true;

   -- component ports
   signal extRst          : sl;                                                      -- [in]
   signal pgpClk          : sl;                                                      -- [out]
   signal pgpRst          : sl;                                                      -- [out]
   signal stableClk       : sl;                                                      -- [out]
   signal pgpTxIn         : Pgp2bTxInType;                                           -- [in]
   signal pgpTxOut        : Pgp2bTxOutType;                                          -- [out]
   signal pgpRxIn         : Pgp2bRxInType;                                           -- [in]
   signal pgpRxOut        : Pgp2bRxOutType;                                          -- [out]
   signal pgpTxMasters    : AxiStreamMasterArray(3 downto 0);                        -- [in]
   signal pgpTxSlaves     : AxiStreamSlaveArray(3 downto 0);                         -- [out]
   signal pgpRxMasters    : AxiStreamMasterArray(3 downto 0);                        -- [out]
   signal pgpRxCtrl       : AxiStreamCtrlArray(3 downto 0);                          -- [in]
   signal gtClkP          : sl;                                                      -- [in]
   signal gtClkN          : sl;                                                      -- [in]
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

   -- component instantiation
   U_Pgp2bGtx7VarLatWrapper: entity work.Pgp2bGtx7VarLatWrapper
      generic map (
         TPD_G              => TPD_G,
         CLKIN_PERIOD_G     => CLKIN_PERIOD_G,
         DIVCLK_DIVIDE_G    => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_F_G  => CLKFBOUT_MULT_F_G,
         CLKOUT0_DIVIDE_F_G => CLKOUT0_DIVIDE_F_G,
         CPLL_REFCLK_SEL_G  => CPLL_REFCLK_SEL_G,
         CPLL_FBDIV_G       => CPLL_FBDIV_G,
         CPLL_FBDIV_45_G    => CPLL_FBDIV_45_G,
         CPLL_REFCLK_DIV_G  => CPLL_REFCLK_DIV_G,
         RXOUT_DIV_G        => RXOUT_DIV_G,
         TXOUT_DIV_G        => TXOUT_DIV_G,
         RX_CLK25_DIV_G     => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G     => TX_CLK25_DIV_G,
         RX_OS_CFG_G        => RX_OS_CFG_G,
         RXCDR_CFG_G        => RXCDR_CFG_G,
         RXDFEXYDEN_G       => RXDFEXYDEN_G,
         RX_DFE_KL_CFG2_G   => RX_DFE_KL_CFG2_G,
         TX_BUF_EN_G        => TX_BUF_EN_G,
         TX_OUTCLK_SRC_G    => TX_OUTCLK_SRC_G,
         TX_DLY_BYPASS_G    => TX_DLY_BYPASS_G,
         TX_PHASE_ALIGN_G   => TX_PHASE_ALIGN_G,
         VC_INTERLEAVE_G    => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G  => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G        => NUM_VC_EN_G,
         AXI_ERROR_RESP_G   => AXI_ERROR_RESP_G,
         TX_ENABLE_G        => TX_ENABLE_G,
         RX_ENABLE_G        => RX_ENABLE_G)
      port map (
         extRst          => extRst,           -- [in]
         pgpClk          => pgpClk,           -- [out]
         pgpRst          => pgpRst,           -- [out]
         stableClk       => stableClk,        -- [out]
         pgpTxIn         => pgpTxIn,          -- [in]
         pgpTxOut        => pgpTxOut,         -- [out]
         pgpRxIn         => pgpRxIn,          -- [in]
         pgpRxOut        => pgpRxOut,         -- [out]
         pgpTxMasters    => pgpTxMasters,     -- [in]
         pgpTxSlaves     => pgpTxSlaves,      -- [out]
         pgpRxMasters    => pgpRxMasters,     -- [out]
         pgpRxCtrl       => pgpRxCtrl,        -- [in]
         gtClkP          => gtClkP,           -- [in]
         gtClkN          => gtClkN,           -- [in]
         gtTxP           => gtTxP,            -- [out]
         gtTxN           => gtTxN,            -- [out]
         gtRxP           => gtRxP,            -- [in]
         gtRxN           => gtRxN,            -- [in]
         txPreCursor     => txPreCursor,      -- [in]
         txPostCursor    => txPostCursor,     -- [in]
         txDiffCtrl      => txDiffCtrl,       -- [in]
         axilClk         => axilClk,          -- [in]
         axilRst         => axilRst,          -- [in]
         axilReadMaster  => axilReadMaster,   -- [in]
         axilReadSlave   => axilReadSlave,    -- [out]
         axilWriteMaster => axilWriteMaster,  -- [in]
         axilWriteSlave  => axilWriteSlave);  -- [out] 

end architecture tb;

----------------------------------------------------------------------------------------------------
