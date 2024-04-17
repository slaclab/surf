-------------------------------------------------------------------------------
-- Title      : PGPv2b: https://confluence.slac.stanford.edu/x/q86fD
-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: Example PGP 3.125 Gbps front end wrapper
-- Note: Default generic configurations are for the KC705 development board
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


library surf;
use surf.StdRtlPkg.all;
use surf.AxiStreamPkg.all;
use surf.Pgp2bPkg.all;
use surf.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp2bGtx7VarLatWrapper is
   generic (
      TPD_G                 : time                    := 1 ns;
      SIM_GTRESET_SPEEDUP_G : string                  := "FALSE";
      SIM_VERSION_G         : string                  := "4.0";
      -- MMCM Configurations (Defaults: gtClkP = 125 MHz Configuration)
      -- See page 40 of https://www.xilinx.com/support/documentation/user_guides/ug362.pdf
      -- CLKIN_PERIOD_G (ns) is 1/2 of the reference rate because the MMCM gets a div/2 copy
      -- MMCM internal frequency is set by:
      --    FVCO = 1000 * CLKFBOUT_MULT_F_G/(CLKIN1_PERIOD_G * DIVCLK_DIVIDE_G)
      -- And must be within the specified operating range of the PLL (around 1Ghz)
      USE_REFCLK_G          : boolean                 := false;
      CLKIN_PERIOD_G        : real                    := 16.0;   -- gtClkP/2
      DIVCLK_DIVIDE_G       : natural range 1 to 106  := 2;
      CLKFBOUT_MULT_F_G     : real range 1.0 to 64.0  := 31.875;
      CLKOUT0_DIVIDE_F_G    : real range 1.0 to 128.0 := 6.375;
      FB_BUFG_G             : boolean                 := false;  -- Simulation might have trouble locking with false
      -- CPLL Configurations (Defaults: gtClkP = 125 MHz Configuration)
      -- See page 48 of https://www.xilinx.com/support/documentation/user_guides/ug476_7Series_Transceivers.pdf
      -- fPllClkOut = fPLLClkIn * ( CPLL_FBDIV_G * CPLL_FBDIV_45_G ) / CPLL_REFCLK_DIV_G
      --    CPPL_FBDIV_G      = 1,2,3,4,5
      --    CPPL_FBDIV_45_G   = 4,5
      --    CPLL_REFCLK_DIV_G = 1,2
      -- fPllClkOut must bet between 1.6Ghz - 3.3Ghz
      CPLL_REFCLK_SEL_G     : bit_vector              := "001";
      CPLL_FBDIV_G          : natural                 := 5;
      CPLL_FBDIV_45_G       : natural                 := 5;
      CPLL_REFCLK_DIV_G     : natural                 := 1;
      -- MGT Configurations (Defaults: gtClkP = 125 MHz Configuration)
      -- Rx Line rate = (fPllClkOut * 2) / RXOUT_DIV_G (1,2,4,6,16)
      -- Tx Line rate = (fPllClkOut * 2) / TXOUT_DIV_G (1,2,4,6,16)
      -- Set RX_CLK25_DIV and TX_CLK25_DIV so that the input reference clock / setting is close to 25Mhz
      RXOUT_DIV_G           : natural                 := 2;
      TXOUT_DIV_G           : natural                 := 2;
      RX_CLK25_DIV_G        : natural                 := 5;
      TX_CLK25_DIV_G        : natural                 := 5;
      RX_OS_CFG_G           : bit_vector              := "0000010000000";
      RXCDR_CFG_G           : bit_vector              := x"03000023ff40200020";
      RXDFEXYDEN_G          : sl                      := '1';
      RX_DFE_KL_CFG2_G      : bit_vector              := x"301148AC";
      -- PGP Settings
      VC_INTERLEAVE_G       : integer                 := 0;      -- No interleave Frames
      PAYLOAD_CNT_TOP_G     : integer                 := 7;      -- Top bit for payload counter
      NUM_VC_EN_G           : integer range 1 to 4    := 4;
      TX_POLARITY_G         : sl                      := '0';
      RX_POLARITY_G         : sl                      := '0';
      TX_ENABLE_G           : boolean                 := true;   -- Enable TX direction
      RX_ENABLE_G           : boolean                 := true);  -- Enable RX direction
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
      gtClkP          : in  sl                     := '0';
      gtClkN          : in  sl                     := '1';
      gtRefClk        : in  sl                     := '0';
      gtRefClkBufg    : in  sl                     := '0';
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
end Pgp2bGtx7VarLatWrapper;

architecture mapping of Pgp2bGtx7VarLatWrapper is

   signal refClk      : sl;
   signal refClkDiv2  : sl := '0';
   signal stableClock : sl;
   signal extRstSync  : sl;

   signal pgpClock : sl;
   signal pgpReset : sl;

begin

   pgpClk    <= pgpClock;
   pgpRst    <= pgpReset;
   stableClk <= stableClock;

   IBUFDS_GEN : if (not USE_REFCLK_G) generate
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

   end generate;

   REFCLK_BUF : if (USE_REFCLK_G) generate
      stableClock <= gtRefClkBufg;
      refClk      <= gtRefClk;
   end generate REFCLK_BUF;


   RstSync_Inst : entity surf.RstSync
      generic map(
         TPD_G => TPD_G)
      port map (
         clk      => stableClock,
         asyncRst => extRst,
         syncRst  => extRstSync);

   ClockManager7_Inst : entity surf.ClockManager7
      generic map(
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => FB_BUFG_G,
         RST_IN_POLARITY_G  => '1',
         NUM_CLOCKS_G       => 1,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => CLKIN_PERIOD_G,
         DIVCLK_DIVIDE_G    => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_F_G  => CLKFBOUT_MULT_F_G,
         CLKOUT0_DIVIDE_F_G => CLKOUT0_DIVIDE_F_G)
      port map(
         clkIn     => stableClock,
         rstIn     => extRstSync,
         clkOut(0) => pgpClock,
         rstOut(0) => pgpReset);

   Pgp2bGtx7VarLat_Inst : entity surf.Pgp2bGtx7VarLat
      generic map (
         TPD_G                 => TPD_G,
         SIM_GTRESET_SPEEDUP_G => SIM_GTRESET_SPEEDUP_G,
         SIM_VERSION_G         => SIM_VERSION_G,
         -- CPLL Configurations
         TX_PLL_G              => "CPLL",
         RX_PLL_G              => "CPLL",
         CPLL_REFCLK_SEL_G     => CPLL_REFCLK_SEL_G,
         CPLL_FBDIV_G          => CPLL_FBDIV_G,
         CPLL_FBDIV_45_G       => CPLL_FBDIV_45_G,
         CPLL_REFCLK_DIV_G     => CPLL_REFCLK_DIV_G,
         -- MGT Configurations
         RXOUT_DIV_G           => RXOUT_DIV_G,
         TXOUT_DIV_G           => TXOUT_DIV_G,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_G,
         RX_OS_CFG_G           => RX_OS_CFG_G,
         RXCDR_CFG_G           => RXCDR_CFG_G,
         RXDFEXYDEN_G          => RXDFEXYDEN_G,
         RX_DFE_KL_CFG2_G      => RX_DFE_KL_CFG2_G,
         -- VC Configuration
         VC_INTERLEAVE_G       => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G     => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G           => NUM_VC_EN_G,
         TX_POLARITY_G         => TX_POLARITY_G,
         RX_POLARITY_G         => RX_POLARITY_G,
         TX_ENABLE_G           => TX_ENABLE_G,
         RX_ENABLE_G           => RX_ENABLE_G)
      port map (
         -- GT Clocking
         stableClk        => stableClock,
         gtCPllRefClk     => refClk,
         gtCPllLock       => open,
         gtQPllRefClk     => '0',
         gtQPllClk        => '0',
         gtQPllLock       => '1',
         gtQPllRefClkLost => '0',
         gtQPllReset      => open,
         -- GT Serial IO
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         -- Tx Clocking
         pgpTxReset       => pgpReset,
         pgpTxRecClk      => open,
         pgpTxClk         => pgpClock,
         pgpTxMmcmReset   => open,
         pgpTxMmcmLocked  => '1',
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
