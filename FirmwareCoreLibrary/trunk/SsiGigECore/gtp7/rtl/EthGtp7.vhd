-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EthGtp7.vhd
-- Author     : Kurtis Nishimura <kurtisn@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2014-06-03
-- Last update: 2014-06-03
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Gtx7 Wrapper for Gigabit Ethernet
-------------------------------------------------------------------------------
-- Copyright (c) 2014 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.GigEthPkg.all;
use work.EthClientPackage.all;
use work.AxiStreamPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity EthGtp7 is
   generic (
      TPD_G             : time       := 1 ns;
      -- Ethernet Configurations
      EN_AUTONEG_G        : boolean          := true;
      UDP_PORT_G          : natural          := 8192;
      TX_REG_SIZE_G       : slv(11 downto 0) := x"168";  -- Default: 360 x 32-bit words = 1.44kB
      EN_JUMBO_G          : boolean          := false;
      TX_JUMBO_SIZE_G     : slv(11 downto 0) := x"4E2";  -- Default: 1250 x 32-bit words = 5kB         
      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string               := "FALSE";
      SIM_VERSION_G         : string               := "1.0";
      STABLE_CLOCK_PERIOD_G : real                 := 4.0E-9;                    --units of seconds
      -- Configure PLL 
      RXOUT_DIV_G           : integer              := 2;
      TXOUT_DIV_G           : integer              := 2;
      RX_CLK25_DIV_G        : integer              := 7;    -- Set by wizard
      TX_CLK25_DIV_G        : integer              := 7;    -- Set by wizard
      PMA_RSV_G             : bit_vector           := x"00000333";               -- Set by wizard
      RX_OS_CFG_G           : bit_vector           := "0001111110000";           -- Set by wizard
      RXCDR_CFG_G           : bit_vector           := x"0000107FE206001041010";  -- Set by wizard
      RXLPM_INCM_CFG_G      : bit                  := '1';  -- Set by wizard
      RXLPM_IPCM_CFG_G      : bit                  := '0';  -- Set by wizard      
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
      PGP_RX_ENABLE_G       : boolean              := true;
      PGP_TX_ENABLE_G       : boolean              := true;
      PAYLOAD_CNT_TOP_G     : integer              := 7;    -- Top bit for payload counter
      VC_INTERLEAVE_G       : integer              := 1;    -- Interleave Frames
      NUM_VC_EN_G           : integer range 1 to 4 := 4);   
   port (
      -- GT Clocking
      stableClk        : in  sl;        -- GT needs a stable clock to "boot up"
      gtQPllOutRefClk  : in  slv(1 downto 0);
      gtQPllOutClk     : in  slv(1 downto 0);
      gtQPllLock       : in  slv(1 downto 0);
      gtQPllRefClkLost : in  slv(1 downto 0);
      gtQPllReset      : out slv(1 downto 0);
      -- GT Serial IO
      gtTxP            : out sl;        -- GT Serial Transmit Positive
      gtTxN            : out sl;        -- GT Serial Transmit Negative
      gtRxP            : in  sl;        -- GT Serial Receive Positive
      gtRxN            : in  sl;        -- GT Serial Receive Negative   
      -- Clocking and Resets
      ethClk62MHz      : in  sl;        -- 62.5 MHz
      ethClk62MHzRst   : in  sl;
      ethClk125MHz     : in  sl;        -- 125 MHz
      ethClk125MHzRst  : in  sl;
      ethTxRecClk      : out sl;        -- recovered clock = 62.5 MHz
      -- Link status signals
      ethRxLinkSync    : out sl;
      ethAutoNegDone   : out sl;
      -- Loopback control for GTX
      loopback         : in  slv(2 downto 0)                  := "000";
      -- MAC address and IP address
      -- Default IP Address is 192.168.  1. 20 
      --                       xC0.xA8.x01.x14
      ipAddr           : in  IPAddrType                       := IP_ADDR_INIT_C;
      -- Default MAC is 01:03:00:56:44:00                            
      macAddr          : in  MacAddrType                      := MAC_ADDR_INIT_C;
      -- Frame Transmit Interface - Array of 4 VCs (ethClk125MHz domain)
      ethTxMasters     : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      ethTxSlaves      : out AxiStreamSlaveArray(3 downto 0);
      -- Frame Receive Interface - Array of 4 VCs (ethClk125MHz domain)
      ethRxMasters     : out AxiStreamMasterArray(3 downto 0);
      ethRxMasterMuxed : out AxiStreamMasterType;
      ethRxCtrl        : in  AxiStreamCtrlArray(3 downto 0));   
end EthGtp7;

architecture mapping of EthGtp7 is

   -- Ethernet's RX Signals
   signal gtRxResetDone : sl;
   signal phyRxLanesIn  : EthRxPhyLaneInType;
   signal phyRxLanesOut : EthRxPhyLaneOutType;

   -- Ethernet's TX Signals
   signal gtTxResetDone : sl;
   signal phyTxLanesOut : EthTxPhyLaneOutType;
   
begin

   --------------------
   -- Gig Ethernet core
   --------------------
   U_GigEthLane : entity work.GigEthLane
      generic map (
         TPD_G               => TPD_G,
         EN_AUTONEG_G        => EN_AUTONEG_G,
         UDP_PORT_G          => UDP_PORT_G,
         TX_REG_SIZE_G       => TX_REG_SIZE_G,
         EN_JUMBO_G          => EN_JUMBO_G,
         TX_JUMBO_SIZE_G     => TX_JUMBO_SIZE_G,
         SIM_RESET_SPEEDUP_G => toBoolean(SIM_GTRESET_SPEEDUP_G),
         SIM_VERSION_G       => SIM_VERSION_G)
      port map (
         -- Clocking
         ethClk125MHz     => ethClk125MHz,
         ethClk125MHzRst  => ethClk125MHzRst,
         ethClk62MHz      => ethClk62MHz,
         ethClk62MHzRst   => ethClk62MHzRst,
         -- Link status signals
         ethRxLinkSync    => ethRxLinkSync,
         ethAutoNegDone   => ethAutoNegDone,
         -- GTX interface signals
         phyRxLaneIn      => phyRxLanesIn,
         phyRxLaneOut     => phyRxLanesOut,
         phyTxLaneOut     => phyTxLanesOut,
         phyRxReady       => gtRxResetDone,
         -- Transmit interfaces from 4 VCs
         ethTxMasters     => ethTxMasters,
         ethTxSlaves      => ethTxSlaves,
         -- Receive interfaces from 4 VCs
         ethRxMasters     => ethRxMasters,
         ethRxMasterMuxed => ethRxMasterMuxed,
         ethRxCtrl        => ethRxCtrl,
         -- MAC address and IP address
         ipAddr           => ipAddr,
         macAddr          => macAddr);     
   
   ---------------------------
   -- Generate the GTP channel
   ---------------------------
   Gtp7Core_Inst : entity work.Gtp7Core
      generic map (
         TPD_G                    => TPD_G,
         SIM_GTRESET_SPEEDUP_G    => SIM_GTRESET_SPEEDUP_G,
         SIM_VERSION_G            => SIM_VERSION_G,
         STABLE_CLOCK_PERIOD_G    => STABLE_CLOCK_PERIOD_G,
         RXOUT_DIV_G              => RXOUT_DIV_G,
         TXOUT_DIV_G              => TXOUT_DIV_G,
         RX_CLK25_DIV_G           => RX_CLK25_DIV_G,
         TX_CLK25_DIV_G           => TX_CLK25_DIV_G,
         PMA_RSV_G                => PMA_RSV_G,
         RX_OS_CFG_G              => RX_OS_CFG_G,
         RXCDR_CFG_G              => RXCDR_CFG_G,
         RXLPM_INCM_CFG_G         => RXLPM_INCM_CFG_G,
         RXLPM_IPCM_CFG_G         => RXLPM_IPCM_CFG_G,
         TX_PLL_G                 => TX_PLL_G,
         RX_PLL_G                 => RX_PLL_G,
         TX_EXT_DATA_WIDTH_G      => 16,
         TX_INT_DATA_WIDTH_G      => 20,
         TX_8B10B_EN_G            => true,
         RX_EXT_DATA_WIDTH_G      => 16,
         RX_INT_DATA_WIDTH_G      => 20,
         RX_8B10B_EN_G            => true,
         TX_BUF_EN_G              => TX_BUF_EN_G,
         TX_OUTCLK_SRC_G          => TX_OUTCLK_SRC_G,
         TX_DLY_BYPASS_G          => TX_DLY_BYPASS_G,
         TX_PHASE_ALIGN_G         => TX_PHASE_ALIGN_G,
         TX_BUF_ADDR_MODE_G       => TX_BUF_ADDR_MODE_G,
         RX_BUF_EN_G              => true,
         RX_OUTCLK_SRC_G          => "OUTCLKPMA",
         RX_USRCLK_SRC_G          => "RXOUTCLK",    -- Not 100% sure, doesn't really matter
         RX_DLY_BYPASS_G          => '1',
         RX_DDIEN_G               => '0',
         RX_BUF_ADDR_MODE_G       => "FULL",
         RX_ALIGN_MODE_G          => "GT",          -- Default
         ALIGN_COMMA_DOUBLE_G     => "FALSE",       -- Default
         ALIGN_COMMA_ENABLE_G     => "1111111111",  -- Default
         ALIGN_COMMA_WORD_G       => 2,             -- Default
         ALIGN_MCOMMA_DET_G       => "TRUE",
         ALIGN_MCOMMA_VALUE_G     => "1010000011",  -- Default
         ALIGN_MCOMMA_EN_G        => '1',
         ALIGN_PCOMMA_DET_G       => "TRUE",
         ALIGN_PCOMMA_VALUE_G     => "0101111100",  -- Default
         ALIGN_PCOMMA_EN_G        => '1',
         SHOW_REALIGN_COMMA_G     => "FALSE",
         RXSLIDE_MODE_G           => "AUTO",
         RX_DISPERR_SEQ_MATCH_G   => "TRUE",        -- Default
         DEC_MCOMMA_DETECT_G      => "TRUE",        -- Default
         DEC_PCOMMA_DETECT_G      => "TRUE",        -- Default
         DEC_VALID_COMMA_ONLY_G   => "FALSE",       -- Default
         CBCC_DATA_SOURCE_SEL_G   => "DECODED",     -- Default
         CLK_COR_SEQ_2_USE_G      => "FALSE",       -- Default
         CLK_COR_KEEP_IDLE_G      => "FALSE",       -- Default
         CLK_COR_MAX_LAT_G        => 21,
         CLK_COR_MIN_LAT_G        => 18,
         CLK_COR_PRECEDENCE_G     => "TRUE",        -- Default
         CLK_COR_REPEAT_WAIT_G    => 0,             -- Default
         CLK_COR_SEQ_LEN_G        => 4,
         CLK_COR_SEQ_1_ENABLE_G   => "1111",        -- Default
         CLK_COR_SEQ_1_1_G        => "0110111100",
         CLK_COR_SEQ_1_2_G        => "0100011100",
         CLK_COR_SEQ_1_3_G        => "0100011100",
         CLK_COR_SEQ_1_4_G        => "0100011100",
         CLK_CORRECT_USE_G        => "TRUE",
         CLK_COR_SEQ_2_ENABLE_G   => "0000",        -- Default
         CLK_COR_SEQ_2_1_G        => "0000000000",  -- Default
         CLK_COR_SEQ_2_2_G        => "0000000000",  -- Default
         CLK_COR_SEQ_2_3_G        => "0000000000",  -- Default
         CLK_COR_SEQ_2_4_G        => "0000000000",  -- Default
         RX_CHAN_BOND_EN_G        => false,
         RX_CHAN_BOND_MASTER_G    => false,
         CHAN_BOND_KEEP_ALIGN_G   => "FALSE",       -- Default
         CHAN_BOND_MAX_SKEW_G     => 10,
         CHAN_BOND_SEQ_LEN_G      => 1,             -- Default
         CHAN_BOND_SEQ_1_1_G      => "0110111100",
         CHAN_BOND_SEQ_1_2_G      => "0111011100",
         CHAN_BOND_SEQ_1_3_G      => "0111011100",
         CHAN_BOND_SEQ_1_4_G      => "0111011100",
         CHAN_BOND_SEQ_1_ENABLE_G => "1111",        -- Default
         CHAN_BOND_SEQ_2_1_G      => "0000000000",  -- Default
         CHAN_BOND_SEQ_2_2_G      => "0000000000",  -- Default
         CHAN_BOND_SEQ_2_3_G      => "0000000000",  -- Default
         CHAN_BOND_SEQ_2_4_G      => "0000000000",  -- Default
         CHAN_BOND_SEQ_2_ENABLE_G => "0000",        -- Default
         CHAN_BOND_SEQ_2_USE_G    => "FALSE",       -- Default
         FTS_DESKEW_SEQ_ENABLE_G  => "1111",        -- Default
         FTS_LANE_DESKEW_CFG_G    => "1111",        -- Default
         FTS_LANE_DESKEW_EN_G     => "FALSE")       -- Default
      port map (
         stableClkIn      => stableClk,
         qPllRefClkIn     => gtQPllOutRefClk,
         qPllClkIn        => gtQPllOutClk,
         qPllLockIn       => gtQPllLock,
         qPllRefClkLostIn => gtQPllRefClkLost,
         qPllResetOut     => gtQPllReset,         
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         rxOutClkOut      => open,
         rxUsrClkIn       => ethClk62MHz,
         rxUsrClk2In      => ethClk62MHz,
         rxUserRdyOut     => open,
         rxMmcmResetOut   => open,
         rxMmcmLockedIn   => '1',
         rxUserResetIn    => ethClk62MHzRst,
         rxResetDoneOut   => gtRxResetDone,
         rxDataValidIn    => '1',
         rxSlideIn        => '0',
         rxDataOut        => phyRxLanesIn.data,
         rxCharIsKOut     => phyRxLanesIn.dataK,
         rxDecErrOut      => phyRxLanesIn.decErr,
         rxDispErrOut     => phyRxLanesIn.dispErr,
         rxPolarityIn     => phyRxLanesOut.polarity,
         rxBufStatusOut   => open,
         rxChBondLevelIn  => "000",
         rxChBondIn       => "0000",
         rxChBondOut      => open,
         txOutClkOut      => ethTxRecClk,
         txUsrClkIn       => ethClk62MHz,
         txUsrClk2In      => ethClk62MHz,
         txUserRdyOut     => open,
         txMmcmResetOut   => open,
         txMmcmLockedIn   => '1',
         txUserResetIn    => ethClk62MHzRst,
         txResetDoneOut   => gtTxResetDone,
         txDataIn         => phyTxLanesOut.data,
         txCharIsKIn      => phyTxLanesOut.dataK,
         txBufStatusOut   => open,
         loopbackIn       => loopback);

end mapping;
