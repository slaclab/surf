-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2bGtx7FixedLatWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-29
-- Last update: 2014-06-17
-- Platform   : Vivado2013.3
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
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp2bGtx7FixedLatWrapper is
   generic (
      -- Select Master or Slave
      MASTER_SEL_G         : boolean              := true;
      RX_CLK_SEL_G         : boolean              := true;
      -- Configure Number of Lanes
      NUM_VC_EN_G          : integer range 1 to 4 := 4;
      -- QPLL Configurations
      QPLL_FBDIV_G         : bit_vector           := "0100100000";
      QPLL_FBDIV_RATIO_G   : bit                  := '1';
      QPLL_REFCLK_DIV_G    : integer              := 1;
      -- CPLL Configurations
      CPLL_FBDIV_G         : integer range 1 to 5 := 4;
      CPLL_FBDIV_45_G      : integer range 4 to 5 := 5;
      CPLL_REFCLK_DIV_G    : integer range 1 to 2 := 1;
      -- MMCM Configurations
      MMCM_CLKIN_PERIOD_G  : real                 := 8.000;
      MMCM_CLKFBOUT_MULT_G : real                 := 8.000;
      MMCM_GTCLK_DIVIDE_G  : real                 := 8.000;
      MMCM_TXCLK_DIVIDE_G  : natural              := 8;
      -- MGT Configurations
      RXOUT_DIV_G          : integer              := 2;
      TXOUT_DIV_G          : integer              := 4;
      RX_CLK25_DIV_G       : integer              := 5;                      -- Set by wizard
      TX_CLK25_DIV_G       : integer              := 5;                      -- Set by wizard
      RX_OS_CFG_G          : bit_vector           := "0000010000000";        -- Set by wizard
      RXCDR_CFG_G          : bit_vector           := x"03000023ff40200020";  -- Set by wizard
      RXDFEXYDEN_G         : sl                   := '0';                    -- Set by wizard
      RX_DFE_KL_CFG2_G     : bit_vector           := x"3008E56A";
      TX_PLL_G             : string               := "QPLL";
      RX_PLL_G             : string               := "CPLL");
   port (
      -- Manual Reset
      extRst           : in  sl;
      -- Status and Clock Signals
      txPllLock        : out sl;
      rxPllLock        : out sl;
      txClk            : out sl;
      rxClk            : out sl;
      stableClk        : out sl;
      -- Non VC Rx Signals
      pgpRxIn          : in  Pgp2bRxInType;
      pgpRxOut         : out Pgp2bRxOutType;
      -- Non VC Tx Signals
      pgpTxIn          : in  Pgp2bTxInType;
      pgpTxOut         : out Pgp2bTxOutType;
      -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
      pgpTxMasters     : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves      : out AxiStreamSlaveArray(3 downto 0);
      -- Frame Receive Interface - 1 Lane, Array of 4 VCs
      pgpRxMasters     : out AxiStreamMasterArray(3 downto 0);
      pgpRxMasterMuxed : out AxiStreamMasterType;
      pgpRxCtrl        : in  AxiStreamCtrlArray(3 downto 0);
      -- GT Pins
      gtClkP           : in  sl;
      gtClkN           : in  sl;
      gtTxP            : out sl;
      gtTxN            : out sl;
      gtRxP            : in  sl;
      gtRxN            : in  sl);  
end Pgp2bGtx7FixedLatWrapper;

architecture rtl of Pgp2bGtx7FixedLatWrapper is

   signal gtClk,
      gtClkDiv2,
      stableClock,
      stableRst,
      locked,
      clkIn1,
      clkOut0,
      clkOut1,
      clkFbIn,
      clkFbOut,
      txClock,
      txRst,
      rxClock,
      rxRecClk,
      pllRefClk,
      gtCPllRefClk,
      gtCPllLock,
      qPllOutClk,
      qPllOutRefClk,
      qPllLock,
      pllLockDetClk,
      qPllRefClkLost,
      qPllReset,
      gtQPllReset : sl := '0';
   
   attribute KEEP_HIERARCHY : string;
   attribute KEEP_HIERARCHY of
      PwrUpRst_Inst,
      QPllCore_1,
      Pgp2bGtx7Fixedlat_Inst : label is "TRUE";
   
begin

   -- Set the status outputs
   txPllLock <= ite((TX_PLL_G = "QPLL"), qPllLock, gtCPllLock);
   rxPllLock <= ite((RX_PLL_G = "QPLL"), qPllLock, gtCPllLock);
   txClk     <= txClock;
   rxClk     <= rxClock;
   stableClk <= stableClock;

   -- GT Reference Clock
   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => gtClkDiv2,
         O     => open);

   BUFG_G : BUFG
      port map (
         I => gtClkDiv2,
         O => stableClock);

   -- Power Up Reset      
   PwrUpRst_Inst : entity work.PwrUpRst
      port map (
         arst   => extRst,
         clk    => stableClock,
         rstOut => stableRst);

   clkIn1 <= ite(MASTER_SEL_G, stableClock, rxClock);

   mmcm_adv_inst : MMCME2_ADV
      generic map(
         BANDWIDTH            => "LOW",
         CLKOUT4_CASCADE      => false,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => false,
         DIVCLK_DIVIDE        => 1,
         CLKFBOUT_MULT_F      => MMCM_CLKFBOUT_MULT_G,
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => false,
         CLKOUT0_DIVIDE_F     => MMCM_GTCLK_DIVIDE_G,
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => false,
         CLKOUT1_DIVIDE       => MMCM_TXCLK_DIVIDE_G,
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => false,
         CLKIN1_PERIOD        => MMCM_CLKIN_PERIOD_G,
         REF_JITTER1          => 0.006)
      port map(
         -- Output clocks
         CLKFBOUT     => clkFbOut,
         CLKFBOUTB    => open,
         CLKOUT0      => clkOut0,
         CLKOUT0B     => open,
         CLKOUT1      => clkOut1,
         CLKOUT1B     => open,
         CLKOUT2      => open,
         CLKOUT2B     => open,
         CLKOUT3      => open,
         CLKOUT3B     => open,
         CLKOUT4      => open,
         CLKOUT5      => open,
         CLKOUT6      => open,
         -- Input clock control
         CLKFBIN      => clkFbIn,
         CLKIN1       => clkIn1,
         CLKIN2       => '0',
         -- Tied to always select the primary input clock
         CLKINSEL     => '1',
         -- Ports for dynamic reconfiguration
         DADDR        => (others => '0'),
         DCLK         => '0',
         DEN          => '0',
         DI           => (others => '0'),
         DO           => open,
         DRDY         => open,
         DWE          => '0',
         -- Ports for dynamic phase shift
         PSCLK        => '0',
         PSEN         => '0',
         PSINCDEC     => '0',
         PSDONE       => open,
         -- Other control and status signals
         LOCKED       => locked,
         CLKINSTOPPED => open,
         CLKFBSTOPPED => open,
         PWRDWN       => '0',
         RST          => stableRst);

   BUFH_1 : BUFH
      port map (
         I => clkFbOut,
         O => clkFbIn); 

   BUFG_2 : BUFG
      port map (
         I => clkOut0,
         O => gtClk); 

   BUFG_3 : BUFG
      port map (
         I => clkOut1,
         O => txClock);  

   txRst <= stableRst;

   gtCPllRefClk  <= gtClk    when((MASTER_SEL_G = true) or (TX_PLL_G = "CPLL")) else stableClock;
   pllRefClk     <= gtClk    when((MASTER_SEL_G = true) or (TX_PLL_G = "QPLL")) else stableClock;
   pllLockDetClk <= stableClock;
   qPllReset     <= stableRst or gtQPllReset;
   rxClock       <= rxRecClk when(RX_CLK_SEL_G = true)                          else txClock;

   QPllCore_1 : entity work.Gtx7QuadPll
      generic map (
         QPLL_REFCLK_SEL_G  => "111",
         QPLL_FBDIV_G       => QPLL_FBDIV_G,
         QPLL_FBDIV_RATIO_G => QPLL_FBDIV_RATIO_G,
         QPLL_REFCLK_DIV_G  => QPLL_REFCLK_DIV_G)
      port map (
         qPllRefClk     => pllRefClk,
         qPllOutClk     => qPllOutClk,
         qPllOutRefClk  => qPllOutRefClk,
         qPllLock       => qPllLock,
         qPllLockDetClk => pllLockDetClk,
         qPllRefClkLost => qPllRefClkLost,
         qPllReset      => qPllReset);                    

   Pgp2bGtx7Fixedlat_Inst : entity work.Pgp2bGtx7Fixedlat
      generic map (
         NUM_VC_EN_G           => NUM_VC_EN_G,
         STABLE_CLOCK_PERIOD_G => 4.0E-9,  --set for longest timeout 
         -- CPLL Settings -
         CPLL_REFCLK_SEL_G     => "111",
         CPLL_FBDIV_G          => CPLL_FBDIV_G,
         CPLL_FBDIV_45_G       => CPLL_FBDIV_45_G,
         CPLL_REFCLK_DIV_G     => CPLL_REFCLK_DIV_G,
         -- CDR Settings -
         RXOUT_DIV_G           => RXOUT_DIV_G,
         TXOUT_DIV_G           => TXOUT_DIV_G,
         RX_CLK25_DIV_G        => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G        => TX_CLK25_DIV_G,
         RX_OS_CFG_G           => RX_OS_CFG_G,
         RXCDR_CFG_G           => RXCDR_CFG_G,
         RXDFEXYDEN_G          => RXDFEXYDEN_G,
         RX_DFE_KL_CFG2_G      => RX_DFE_KL_CFG2_G,
         -- Configure PLL sources
         TX_PLL_G              => TX_PLL_G,
         RX_PLL_G              => RX_PLL_G)
      port map (
         -- GT Clocking
         stableClk        => stableClock,
         gtCPllRefClk     => gtCPllRefClk,
         gtCPllLock       => gtCPllLock,
         gtQPllRefClk     => qPllOutRefClk,
         gtQPllClk        => qPllOutClk,
         gtQPllLock       => qPllLock,
         gtQPllRefClkLost => qPllRefClkLost,
         gtQPllReset      => gtQPllReset,
         gtRxRefClkBufg   => stableClock,
         -- Gt Serial IO
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         -- Tx Clocking
         pgpTxReset       => txRst,
         pgpTxClk         => txClock,
         -- Rx clocking
         pgpRxReset       => extRst,
         pgpRxRecClk      => rxRecClk,
         pgpRxClk         => rxClock,
         pgpRxMmcmReset   => open,
         pgpRxMmcmLocked  => locked,
         -- Non VC Rx Signals
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         -- Frame Receive Interface - 1 Lane, Array of 4 VCs
         pgpRxMasters     => pgpRxMasters,
         pgpRxMasterMuxed => pgpRxMasterMuxed,
         pgpRxCtrl        => pgpRxCtrl);  
end rtl;
