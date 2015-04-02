-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Pgp2bGth7VarLat.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-01
-- Last update: 2015-04-01
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gth7 Wrapper
--
-- Dependencies:  ^/pgp2_core/trunk/rtl/core/Pgp2RxWrapper.vhd
--                ^/pgp2_core/trunk/rtl/core/Pgp2TxWrapper.vhd
--                ^/StdLib/trunk/rtl/CRC32Rtl.vhd
--                ^/MgtLib/trunk/rtl/gth7/Gth7Core.vhd
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.Pgp2bPkg.all;

entity Pgp2bGth7VarLat is
   generic (
      TPD_G                 : time       := 1 ns;
      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "2.0";
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

      PMA_RSV_G    : bit_vector := x"00000080";
      RX_OS_CFG_G  : bit_vector := "0000010000000";           -- Set by wizard
      RXCDR_CFG_G  : bit_vector := x"0002007FE1000C2200018";  -- Set by wizard
      RXDFEXYDEN_G : sl         := '1';                       -- Set by wizard

      -- Configure PLL sources
      TX_PLL_G : string := "QPLL";
      RX_PLL_G : string := "CPLL";

      -- Configure Buffer usage
      TX_BUF_EN_G        : boolean := true;
      TX_OUTCLK_SRC_G    : string  := "OUTCLKPMA";
      TX_DLY_BYPASS_G    : sl      := '1';
      TX_PHASE_ALIGN_G   : string  := "NONE";
      TX_BUF_ADDR_MODE_G : string  := "FULL";

      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PGP_RX_ENABLE_G   : boolean              := true;
      PGP_TX_ENABLE_G   : boolean              := true;
      PAYLOAD_CNT_TOP_G : integer              := 7;  -- Top bit for payload counter
      VC_INTERLEAVE_G   : integer              := 1;  -- Interleave Frames
      NUM_VC_EN_G       : integer range 1 to 4 := 4);
   port (
      -- GT Clocking
      stableClk        : in  sl;                      -- GT needs a stable clock to "boot up"
      gtCPllRefClk     : in  sl;                      -- Drives CPLL if used
      gtCPllLock       : out sl;
      gtQPllRefClk     : in  sl;                      -- Signals from QPLL if used
      gtQPllClk        : in  sl;
      gtQPllLock       : in  sl;
      gtQPllRefClkLost : in  sl;
      gtQPllReset      : out sl;
      -- Gt Serial IO
      gtTxP            : out sl;                      -- GT Serial Transmit Positive
      gtTxN            : out sl;                      -- GT Serial Transmit Negative
      gtRxP            : in  sl;                      -- GT Serial Receive Positive
      gtRxN            : in  sl;                      -- GT Serial Receive Negative
      -- Tx Clocking
      pgpTxReset       : in  sl;
      pgpTxClk         : in  sl;
      pgpTxRecClk      : out sl;                      -- recovered clock
      pgpTxMmcmReset   : out sl;
      pgpTxMmcmLocked  : in  sl;
      -- Rx clocking
      pgpRxReset       : in  sl;
      pgpRxRecClk      : out sl;                      -- recovered clock
      pgpRxClk         : in  sl;
      pgpRxMmcmReset   : out sl;
      pgpRxMmcmLocked  : in  sl;
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
      pgpRxCtrl        : in  AxiStreamCtrlArray(3 downto 0));
end Pgp2bGth7VarLat;

architecture mapping of Pgp2bGth7VarLat is

begin

   MuliLane_Inst : entity work.Pgp2bGth7MultiLane
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
         PGP_RX_ENABLE_G       => PGP_RX_ENABLE_G,
         PGP_TX_ENABLE_G       => PGP_TX_ENABLE_G,
         PAYLOAD_CNT_TOP_G     => PAYLOAD_CNT_TOP_G,
         VC_INTERLEAVE_G       => VC_INTERLEAVE_G,
         NUM_VC_EN_G           => NUM_VC_EN_G)
      port map (
         -- GT Clocking
         stableClk        => stableClk,
         gtCPllRefClk     => gtCPllRefClk,
         gtCPllLock       => gtCPllLock,
         gtQPllRefClk     => gtQPllRefClk,
         gtQPllClk        => gtQPllClk,
         gtQPllLock       => gtQPllLock,
         gtQPllRefClkLost => gtQPllRefClkLost,
         gtQPllReset      => gtQPllReset,
         -- Gt Serial IO
         gtTxP(0)         => gtTxP,
         gtTxN(0)         => gtTxN,
         gtRxP(0)         => gtRxP,
         gtRxN(0)         => gtRxN,
         -- Tx Clocking
         pgpTxReset       => pgpTxReset,
         pgpTxRecClk      => pgpTxRecClk,
         pgpTxClk         => pgpTxClk,
         pgpTxMmcmReset   => pgpTxMmcmReset,
         pgpTxMmcmLocked  => pgpTxMmcmLocked,
         -- Rx clocking
         pgpRxReset       => pgpRxReset,
         pgpRxRecClk      => pgpRxRecClk,
         pgpRxClk         => pgpRxClk,
         pgpRxMmcmReset   => pgpRxMmcmReset,
         pgpRxMmcmLocked  => pgpRxMmcmLocked,
         -- Non VC Rx Signals
         pgpRxIn          => pgpRxIn,
         pgpRxOut         => pgpRxOut,
         -- Non VC Tx Signals
         pgpTxIn          => pgpTxIn,
         pgpTxOut         => pgpTxOut,
         -- Frame Transmit Interface - Array of 4 VCs
         pgpTxMasters     => pgpTxMasters,
         pgpTxSlaves      => pgpTxSlaves,
         -- Frame Receive Interface - Array of 4 VCs
         pgpRxMasters     => pgpRxMasters,
         pgpRxMasterMuxed => pgpRxMasterMuxed,
         pgpRxCtrl        => pgpRxCtrl);

end mapping;
