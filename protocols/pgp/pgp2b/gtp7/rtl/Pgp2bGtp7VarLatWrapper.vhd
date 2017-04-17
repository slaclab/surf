-------------------------------------------------------------------------------
-- File       : Pgp2bGtp7VarLatWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-29
-- Last update: 2016-12-16
-------------------------------------------------------------------------------
-- Description: Example PGP2b front end wrapper
-- Note: Default generic configurations are for the AC701 development board
-- Note: Default uses 125 MHz reference clock to generate 3.125 Gbps PGP link
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

library unisim;
use unisim.vcomponents.all;

entity Pgp2bGtp7VarLatWrapper is
   generic (
      TPD_G                : time                    := 1 ns;
      SIMULATION_G         : boolean                 := false;
      -- MMCM Configurations
      CLKIN_PERIOD_G       : real                    := 6.4;
      DIVCLK_DIVIDE_G      : natural range 1 to 106  := 1;
      CLKFBOUT_MULT_F_G    : real range 1.0 to 64.0  := 6.0;
      CLKOUT0_DIVIDE_F_G   : real range 1.0 to 128.0 := 6.0;
      -- Quad PLL Configurations (Defaults: gtClkP = 125 MHz Configuration)
      QPLL_REFCLK_SEL_G    : bit_vector              := "001";
      QPLL_FBDIV_IN_G      : natural range 1 to 5    := 5;
      QPLL_FBDIV_45_IN_G   : natural range 4 to 5    := 5;
      QPLL_REFCLK_DIV_IN_G : natural range 1 to 2    := 1;
      -- MGT Configurations (Defaults: gtClkP = 125 MHz Configuration)
      RXOUT_DIV_G          : natural                 := 2;
      TXOUT_DIV_G          : natural                 := 2;
      RX_CLK25_DIV_G       : natural                 := 5;
      TX_CLK25_DIV_G       : natural                 := 5;
      RX_OS_CFG_G          : bit_vector              := "0000010000000";
      RXCDR_CFG_G          : bit_vector              := x"0001107FE206021081010";
      RXLPM_INCM_CFG_G     : bit                     := '0';
      RXLPM_IPCM_CFG_G     : bit                     := '1';
      -- Configure PGP
      RX_ENABLE_G          : boolean                 := true;
      TX_ENABLE_G          : boolean                 := true;
      AXI_ERROR_RESP_G     : slv(1 downto 0)         := AXI_RESP_DECERR_C;
      PAYLOAD_CNT_TOP_G    : integer                 := 7;     -- Top bit for payload counter
      VC_INTERLEAVE_G      : integer                 := 1;     -- Interleave Frames
      NUM_VC_EN_G          : integer range 1 to 4    := 4);
   port (
      -- Manual Reset
      extRst          : in  sl;
      -- Clocks and Reset
      pgpClk          : out sl;
      pgpRst          : out sl;
      stableClk       : out sl;
      -- Non VC TX Signals
      pgpTxIn         : in  Pgp2bTxInType;
      pgpTxOut        : out Pgp2bTxOutType;
      -- Non VC RX Signals
      pgpRxIn         : in  Pgp2bRxInType;
      pgpRxOut        : out Pgp2bRxOutType;
      -- Frame TX Interface
      pgpTxMasters    : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves     : out AxiStreamSlaveArray(3 downto 0);
      -- Frame RX Interface
      pgpRxMasters    : out AxiStreamMasterArray(3 downto 0);
      pgpRxCtrl       : in  AxiStreamCtrlArray(3 downto 0);
      -- GT Pins
      gtClkP          : in  sl;
      gtClkN          : in  sl;
      gtTxP           : out sl;
      gtTxN           : out sl;
      gtRxP           : in  sl;
      gtRxN           : in  sl;
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
end Pgp2bGtp7VarLatWrapper;

architecture mapping of Pgp2bGtp7VarLatWrapper is

   signal refClk      : sl;
   signal refClkDiv2  : sl;
   signal stableClock : sl;
   signal extRstSync  : sl;

   signal pgpClock        : sl;
   signal pgpTxRecClk     : sl;
   signal pgpReset        : sl;
   signal pgpTxMmcmLocked : sl;

   signal pllRefClk        : slv(1 downto 0);
   signal pllLockDetClk    : slv(1 downto 0);
   signal qPllReset        : slv(1 downto 0);
   signal gtQPllOutRefClk  : slv(1 downto 0);
   signal gtQPllOutClk     : slv(1 downto 0);
   signal gtQPllLock       : slv(1 downto 0);
   signal gtQPllRefClkLost : slv(1 downto 0);
   signal gtQPllReset      : slv(1 downto 0);

begin

   pgpClk    <= pgpClock;
   pgpRst    <= pgpReset;
   stableClk <= stableClock;

   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => refClkDiv2,
         O     => refClk);

   BUFG_Inst : BUFG
      port map (
         I => refClkDiv2,
         O => stableClock);

   RstSync_Inst : entity work.RstSync
      generic map(
         TPD_G => TPD_G)
      port map (
         clk      => stableClock,
         asyncRst => extRst,
         syncRst  => extRstSync);

--    U_BUFG_PGP : BUFG
--       port map (
--          I => pgpTxRecClk,
--          O => pgpClock);

   ClockManager7_Inst : entity work.ClockManager7
      generic map(
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => true,
         FB_BUFG_G          => true,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 1,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => CLKIN_PERIOD_G,
         DIVCLK_DIVIDE_G    => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_F_G  => CLKFBOUT_MULT_F_G,
         CLKOUT0_DIVIDE_F_G => CLKOUT0_DIVIDE_F_G)
      port map(
         clkIn     => pgpTxRecClk,
         rstIn     => extRstSync,
         clkOut(0) => pgpClock,
         rstOut(0) => open,
         locked    => pgpTxMmcmLocked);

   -- PLL0 Port Mapping
   pllRefClk(0)     <= refClk;
   pllLockDetClk(0) <= stableClock;
   qPllReset(0)     <= pgpReset or gtQPllReset(0);

   -- PLL1 Port Mapping
   pllRefClk(1)     <= refClk;
   pllLockDetClk(1) <= stableClock;
   qPllReset(1)     <= pgpReset or gtQPllReset(1);

   Quad_Pll_Inst : entity work.Gtp7QuadPll
      generic map (
         TPD_G                => TPD_G,
         SIM_RESET_SPEEDUP_G  => ite(SIMULATION_G, "TRUE", "FALSE"),
         PLL0_REFCLK_SEL_G    => QPLL_REFCLK_SEL_G,
         PLL0_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         PLL0_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         PLL0_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G,
         PLL1_REFCLK_SEL_G    => QPLL_REFCLK_SEL_G,
         PLL1_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         PLL1_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         PLL1_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G)
      port map (
         qPllRefClk     => pllRefClk,
         qPllOutClk     => gtQPllOutClk,
         qPllOutRefClk  => gtQPllOutRefClk,
         qPllLock       => gtQPllLock,
         qPllLockDetClk => pllLockDetClk,
         qPllRefClkLost => gtQPllRefClkLost,
         qPllReset      => qPllReset);

   Pgp2bGtp7VarLat_Inst : entity work.Pgp2bGtp7VarLat
      generic map (
         TPD_G                 => TPD_G,
         SIM_GTRESET_SPEEDUP_G => ite(SIMULATION_G, "TRUE", "FALSE"),
         -- MGT Configurations
         RXOUT_DIV_G           => RXOUT_DIV_G,
         TXOUT_DIV_G           => TXOUT_DIV_G,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_G,
         RX_OS_CFG_G           => RX_OS_CFG_G,
         RXCDR_CFG_G           => RXCDR_CFG_G,
         RXLPM_INCM_CFG_G      => RXLPM_INCM_CFG_G,
         RXLPM_IPCM_CFG_G      => RXLPM_IPCM_CFG_G,
         -- Configure PLL sources
         TX_PLL_G              => "PLL0",
         RX_PLL_G              => "PLL1",
         -- Configure PGP
         RX_ENABLE_G           => RX_ENABLE_G,
         TX_ENABLE_G           => TX_ENABLE_G,
         AXI_ERROR_RESP_G      => AXI_ERROR_RESP_G,
         PAYLOAD_CNT_TOP_G     => PAYLOAD_CNT_TOP_G,
         VC_INTERLEAVE_G       => VC_INTERLEAVE_G,
         NUM_VC_EN_G           => NUM_VC_EN_G)
      port map (
         -- GT Clocking
         stableClk        => stableClock,
         gtQPllOutRefClk  => gtQPllOutRefClk,
         gtQPllOutClk     => gtQPllOutClk,
         gtQPllLock       => gtQPllLock,
         gtQPllRefClkLost => gtQPllRefClkLost,
         gtQPllReset      => gtQPllReset,
         -- GT Serial IO
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         -- Tx Clocking
         pgpTxReset       => extRstSync,
         pgpTxRecClk      => pgpTxRecClk,
         pgpTxClk         => pgpClock,
         pgpTxMmcmReset   => open,
         pgpTxMmcmLocked  => pgpTxMmcmLocked,
         -- Rx clocking
         pgpRxReset       => pgpReset,
         pgpRxRecClk      => open,
         pgpRxClk         => pgpClock,
         pgpRxMmcmReset   => open,
         pgpRxMmcmLocked  => '1',
         -- Non VC TX Signals
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         -- Non VC RX Signals
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         -- Frame TX Interface
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         -- Frame RX Interface
         pgpRxMasters     => pgpRxMasters,
         pgpRxCtrl        => pgpRxCtrl,
         -- Debug Interface 
         txPreCursor      => txPreCursor,
         txPostCursor     => txPostCursor,
         txDiffCtrl       => txDiffCtrl,
         -- AXI-Lite Interface 
         axilClk          => axilClk,
         axilRst          => axilRst,
         axilReadMaster   => axilReadMaster,
         axilReadSlave    => axilReadSlave,
         axilWriteMaster  => axilWriteMaster,
         axilWriteSlave   => axilWriteSlave);

end mapping;
