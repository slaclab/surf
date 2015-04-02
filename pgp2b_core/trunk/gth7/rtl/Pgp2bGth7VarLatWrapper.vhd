-------------------------------------------------------------------------------
-- Title      : Example Code
-------------------------------------------------------------------------------
-- File       : Pgp2bGth7VarLatWrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-01
-- Last update: 2015-04-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Example PGP 3.125 Gbps front end wrapper
-- Note: Default generic configurations are for the Digilent NetFPGA-SUME development board
-- Note: Default uses SFP_CLK = 312.5 MHz reference clock
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;

library unisim;
use unisim.vcomponents.all;

entity Pgp2bGth7VarLatWrapper is
   generic (
      TPD_G             : time                 := 1 ns;
      -- CPLL Configurations (Defaults: gtClkP = 312.5 MHz Configuration)
      CPLL_REFCLK_SEL_G : bit_vector           := "001";
      CPLL_FBDIV_G      : natural              := 2;
      CPLL_FBDIV_45_G   : natural              := 5;
      CPLL_REFCLK_DIV_G : natural              := 1;
      -- MGT Configurations (Defaults: gtClkP = 312.5 MHz Configuration)
      RXOUT_DIV_G       : natural              := 2;
      TXOUT_DIV_G       : natural              := 2;
      RX_CLK25_DIV_G    : natural              := 13;
      TX_CLK25_DIV_G    : natural              := 13;
      RX_OS_CFG_G       : bit_vector           := "0000010000000";           -- Set by wizard
      RXCDR_CFG_G       : bit_vector           := x"0002007FE1000C2200018";  -- Set by wizard
      RXDFEXYDEN_G      : sl                   := '1';                       -- Set by wizard 
      -- Configure Number of VC Lanes
      NUM_VC_EN_G       : natural range 1 to 4 := 4);
   port (
      -- Clocks and Reset
      pgpClk       : out sl;
      pgpRst       : out sl;
      -- Non VC TX Signals
      pgpTxIn      : in  Pgp2bTxInType;
      pgpTxOut     : out Pgp2bTxOutType;
      -- Non VC RX Signals
      pgpRxIn      : in  Pgp2bRxInType;
      pgpRxOut     : out Pgp2bRxOutType;
      -- Frame TX Interface
      pgpTxMasters : in  AxiStreamMasterArray(3 downto 0);
      pgpTxSlaves  : out AxiStreamSlaveArray(3 downto 0);
      -- Frame RX Interface
      pgpRxMasters : out AxiStreamMasterArray(3 downto 0);
      pgpRxCtrl    : in  AxiStreamCtrlArray(3 downto 0);
      -- GT Pins
      gtClkP       : in  sl;
      gtClkN       : in  sl;
      gtTxP        : out sl;
      gtTxN        : out sl;
      gtRxP        : in  sl;
      gtRxN        : in  sl);  
end Pgp2bGth7VarLatWrapper;

architecture mapping of Pgp2bGth7VarLatWrapper is

   signal refClk     : sl;
   signal refClkDiv2 : sl;

   signal pgpClock : sl;
   signal pgpReset : sl;

begin

   pgpClk <= pgpClock;
   pgpRst <= pgpReset;

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
         O => pgpClock);           

   PwrUpRst_Inst : entity work.PwrUpRst
      generic map(
         TPD_G => TPD_G)   
      port map (
         clk    => pgpClock,
         rstOut => pgpReset);          

   Pgp2bGth7VarLat_Inst : entity work.Pgp2bGth7VarLat
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
         -- VC Configuration
         NUM_VC_EN_G       => NUM_VC_EN_G)          
      port map (
         -- GT Clocking
         stableClk        => pgpClock,
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
         pgpRxCtrl        => pgpRxCtrl);      

end mapping;
