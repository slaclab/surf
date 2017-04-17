-------------------------------------------------------------------------------
-- File       : Pgp2bGtx7VarLatWrapper.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-29
-- Last update: 2016-08-24
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

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;
use work.AxiLitePkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp2bGtx7VarLatWrapper is
   generic (
      TPD_G              : time                    := 1 ns;
      -- MMCM Configurations (Defaults: gtClkP = 125 MHz Configuration)
      CLKIN_PERIOD_G     : real                    := 16.0;   -- gtClkP/2
      DIVCLK_DIVIDE_G    : natural range 1 to 106  := 2;
      CLKFBOUT_MULT_F_G  : real range 1.0 to 64.0  := 31.875;
      CLKOUT0_DIVIDE_F_G : real range 1.0 to 128.0 := 6.375;
      -- CPLL Configurations (Defaults: gtClkP = 125 MHz Configuration)
      CPLL_REFCLK_SEL_G  : bit_vector              := "001";
      CPLL_FBDIV_G       : natural                 := 5;
      CPLL_FBDIV_45_G    : natural                 := 5;
      CPLL_REFCLK_DIV_G  : natural                 := 1;
      -- MGT Configurations (Defaults: gtClkP = 125 MHz Configuration)
      RXOUT_DIV_G        : natural                 := 2;
      TXOUT_DIV_G        : natural                 := 2;
      RX_CLK25_DIV_G     : natural                 := 5;
      TX_CLK25_DIV_G     : natural                 := 5;
      RX_OS_CFG_G        : bit_vector              := "0000010000000";
      RXCDR_CFG_G        : bit_vector              := x"03000023ff40200020";
      RXDFEXYDEN_G       : sl                      := '1';
      RX_DFE_KL_CFG2_G   : bit_vector              := x"301148AC";
      -- PGP Settings
      VC_INTERLEAVE_G    : integer                 := 0;      -- No interleave Frames
      PAYLOAD_CNT_TOP_G  : integer                 := 7;      -- Top bit for payload counter
      NUM_VC_EN_G        : integer range 1 to 4    := 4;
      AXI_ERROR_RESP_G   : slv(1 downto 0)         := AXI_RESP_DECERR_C;
      TX_ENABLE_G        : boolean                 := true;   -- Enable TX direction
      RX_ENABLE_G        : boolean                 := true);  -- Enable RX direction
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
end Pgp2bGtx7VarLatWrapper;

architecture mapping of Pgp2bGtx7VarLatWrapper is

   signal refClk      : sl;
   signal refClkDiv2  : sl;
   signal stableClock : sl;
   signal extRstSync  : sl;

   signal pgpClock : sl;
   signal pgpReset : sl;

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

   ClockManager7_Inst : entity work.ClockManager7
      generic map(
         TPD_G              => TPD_G,
         TYPE_G             => "MMCM",
         INPUT_BUFG_G       => false,
         FB_BUFG_G          => false,
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

   Pgp2bGtx7VarLat_Inst : entity work.Pgp2bGtx7VarLat
      generic map (
         TPD_G             => TPD_G,
         -- CPLL Configurations
         TX_PLL_G          => "CPLL",
         RX_PLL_G          => "CPLL",
         CPLL_REFCLK_SEL_G => CPLL_REFCLK_SEL_G,
         CPLL_FBDIV_G      => CPLL_FBDIV_G,
         CPLL_FBDIV_45_G   => CPLL_FBDIV_45_G,
         CPLL_REFCLK_DIV_G => CPLL_REFCLK_DIV_G,
         -- MGT Configurations
         RXOUT_DIV_G       => RXOUT_DIV_G,
         TXOUT_DIV_G       => TXOUT_DIV_G,
         RX_CLK25_DIV_G    => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G    => TX_CLK25_DIV_G,
         RX_OS_CFG_G       => RX_OS_CFG_G,
         RXCDR_CFG_G       => RXCDR_CFG_G,
         RXDFEXYDEN_G      => RXDFEXYDEN_G,
         RX_DFE_KL_CFG2_G  => RX_DFE_KL_CFG2_G,
         -- VC Configuration
         VC_INTERLEAVE_G   => VC_INTERLEAVE_G,
         PAYLOAD_CNT_TOP_G => PAYLOAD_CNT_TOP_G,
         NUM_VC_EN_G       => NUM_VC_EN_G,
         AXI_ERROR_RESP_G  => AXI_ERROR_RESP_G,
         TX_ENABLE_G       => TX_ENABLE_G,
         RX_ENABLE_G       => RX_ENABLE_G)     
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
