-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2Gtx7VarLatWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-01-29
-- Last update: 2014-01-29
-- Platform   : Vivado2013.3
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- This file is part of 'SLAC PGP2 Core'.
-- It is subject to the license terms in the LICENSE.txt file found in the 
-- top-level directory of this distribution and at: 
--    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
-- No part of 'SLAC PGP2 Core', including this file, 
-- may be copied, modified, propagated, or distributed except according to 
-- the terms contained in the LICENSE.txt file.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.Pgp2CoreTypesPkg.all;
use work.StdRtlPkg.all;
use work.VcPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp2Gtx7VarLatWrapper is
   generic (
      -- Configure Number of Lanes
      NUM_VC_EN_G          : integer range 1 to 4 := 4;
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
      TXOUT_DIV_G          : integer              := 2;
      RX_CLK25_DIV_G       : integer              := 5;    -- Set by wizard
      TX_CLK25_DIV_G       : integer              := 5;    -- Set by wizard
      RX_OS_CFG_G          : bit_vector           := "0000010000000";  -- Set by wizard
      RXCDR_CFG_G          : bit_vector           := x"03000023ff40200020";  -- Set by wizard
      RXDFEXYDEN_G         : sl                   := '0';  -- Set by wizard
      RX_DFE_KL_CFG2_G     : bit_vector           := x"3008E56A");  -- Set by wizard
   port (
      -- Manual Reset
      extRst           : in  sl;
      -- Status and Clock Signals
      pllLock          : out sl;
      locClk           : out sl;
      locRst           : out sl;
      stableClk        : out sl;
      -- Non VC Rx Signals
      pgpRxIn          : in  PgpRxInType;
      pgpRxOut         : out PgpRxOutType;
      -- Non VC Tx Signals
      pgpTxIn          : in  PgpTxInType;
      pgpTxOut         : out PgpTxOutType;
      -- Frame Transmit Interface - 1 Lane, Array of 4 VCs
      pgpVcTxQuadIn    : in  VcTxQuadInType;
      pgpVcTxQuadOut   : out VcTxQuadOutType;
      -- Frame Receive Interface - 1 Lane, Array of 4 VCs
      pgpVcRxCommonOut : out VcRxCommonOutType;
      pgpVcRxQuadOut   : out VcRxQuadOutType;
      -- GT loopback control
      loopback         : in  slv(2 downto 0);  -- GT Serial Loopback Control      
      -- GT Pins
      gtClkP           : in  sl;
      gtClkN           : in  sl;
      gtTxP            : out sl;
      gtTxN            : out sl;
      gtRxP            : in  sl;
      gtRxN            : in  sl);  
end Pgp2Gtx7VarLatWrapper;

architecture rtl of Pgp2Gtx7VarLatWrapper is

   signal gtClkDiv2,
      stableClock,
      stableRst,
      locked,
      clkOut0,
      clkOut1,
      clkFbIn,
      clkFbOut,
      txClock,
      gtCPllRefClk,
      gtCPllLock,
      qPllOutClk,
      qPllOutRefClk,
      qPllLock,
      qPllRefClkLost : sl := '0';
begin
   -- Set the status outputs
   pllLock   <= gtCPllLock;
   locClk    <= txClock;
   locRst    <= not(locked);
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
         CLKIN1       => stableClock,
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
         O => gtCPllRefClk); 

   BUFG_3 : BUFG
      port map (
         I => clkOut1,
         O => txClock);  
   
   --Not using the Quad PLL any more
   qPllOutRefClk  <= '0';
   qPllOutClk     <= '0';
   qPllLock       <= '1';
   qPllRefClkLost <= '0';                     

   Pgp2Gtx7MultiLane_Inst : entity work.Pgp2Gtx7MultiLane
      generic map (
         NUM_VC_EN_G           => NUM_VC_EN_G,
         STABLE_CLOCK_PERIOD_G => 4.0E-9,  --set for longest timeout 
         LANE_CNT_G            => 1,       -- no channel bonding
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
         TX_PLL_G              => "CPLL",
         RX_PLL_G              => "CPLL")
      port map (
         -- GT Clocking
         stableClk        => stableClock,
         gtCPllRefClk     => gtCPllRefClk,
         gtCPllLock       => gtCPllLock,
         gtQPllRefClk     => qPllOutRefClk,
         gtQPllClk        => qPllOutClk,
         gtQPllLock       => qPllLock,
         gtQPllRefClkLost => qPllRefClkLost,
         gtQPllReset      => open,
         -- Gt Serial IO
         gtTxP(0)         => gtTxP,
         gtTxN(0)         => gtTxN,
         gtRxP(0)         => gtRxP,
         gtRxN(0)         => gtRxN,
         -- Tx Clocking
         pgpTxReset       => stableRst,
         pgpTxClk         => txClock,
         pgpTxMmcmReset   => open,
         pgpTxMmcmLocked  => locked,
         -- Rx clocking
         pgpRxReset       => stableRst,
         pgpRxRecClk      => open,
         pgpRxClk         => txClock,
         pgpRxMmcmReset   => open,
         pgpRxMmcmLocked  => locked,
         -- Non VC Rx Signals
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         -- Frame Transmit Interface - Array of 4 VCs
         pgpVcTxQuadIn    => pgpVcTxQuadIn,
         pgpVcTxQuadOut   => pgpVcTxQuadOut,
         -- Frame Receive Interface - Array of 4 VCs
         pgpVcRxCommonOut => pgpVcRxCommonOut,
         pgpVcRxQuadOut   => pgpVcRxQuadOut,
         -- GT loopback control
         loopback         => loopback);  
end rtl;
