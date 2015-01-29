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
use ieee.numeric_std.all;

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
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "4.0";
      STABLE_CLOCK_PERIOD_G : real       := 8.0E-9;  --units of seconds
      -- QPLL (GTPE2_COMMON) settings
      PLL0_REFCLK_SEL_G     : bit_vector := "001";
      PLL1_REFCLK_SEL_G     : bit_vector := "001";
      QPLL_FBDIV_IN_G       : integer range 1 to 5 := 4;
      QPLL_FBDIV_45_IN_G    : integer range 4 to 5 := 5;
      QPLL_REFCLK_DIV_IN_G  : integer range 1 to 2 := 1;
      -- Gtp7Core settings
      RXOUT_DIV_G           : integer    := 4;
      TXOUT_DIV_G           : integer    := 4;
      TX_PLL_G              : string     := "PLL0";
      RX_PLL_G              : string     := "PLL1"
   );
   port (
      stableRst        : in sl;
      -- Gt Serial IO
      gtTxP            : out sl;  -- GT Serial Transmit Positive
      gtTxN            : out sl;  -- GT Serial Transmit Negative
      gtRxP            : in  sl;  -- GT Serial Receive Positive
      gtRxN            : in  sl;  -- GT Serial Receive Negative
      -- Gt clocking
      gtClkP           : in  sl;
      gtClkN           : in  sl;
      -- (Not recommended) fabric clock to GTX
      gtFabricClk      : in  sl := '0';
      -- Input clocking
      stableClk        : in  sl;
      -- Output clocking
      ethClk           : out sl;
      ethClk62         : out sl;
      -- Link status signals
      ethRxLinkSync    : out sl;
      ethAutoNegDone   : out sl;
      -- Transmit interfaces from 4 VCs
      ethTxMasters     : in  AxiStreamMasterArray(3 downto 0) := (others => AXI_STREAM_MASTER_INIT_C);
      ethTxSlaves      : out AxiStreamSlaveArray(3 downto 0);
      -- Receive interfaces from 4 VCs
      ethRxMasters     : out AxiStreamMasterArray(3 downto 0);
      ethRxMasterMuxed : out AxiStreamMasterType;
      ethRxCtrl        : in  AxiStreamCtrlArray(3 downto 0);
      -- Loopback control for GTX
      loopback         : in  slv(2 downto 0) := "000";
      -- MAC address and IP address
      -- Default IP Address is 192.168.  1. 20 
      --                       xC0.xA8.x01.x14
      ipAddr           : in IPAddrType := (3 => x"C0",2 => x"A8",1 => x"01",0 => x"14");
      -- Default MAC is 01:03:00:56:44:00                            
      macAddr          : in MacAddrType := (5 => x"01",4 => x"03",3 => x"00",2 => x"56",1 => x"44",0 => x"00")
   );      
end EthGtp7;

-- Define architecture
architecture rtl of EthGtp7 is

   ---------------------------------------------------------------------------
   -- Constants
   ---------------------------------------------------------------------------

   -- PgpRx Signals
   signal pgpRxRecClock   : sl;
   signal gtRxResetDone   : sl;
   signal gtRxUserReset   : sl;
   signal gtRxUserResetIn : sl;
   signal phyRxLanesIn    : EthRxPhyLaneInArray(0 downto 0);
   signal phyRxLanesOut   : EthRxPhyLaneOutArray(0 downto 0);
   signal phyRxInit       : sl;

   -- Rx Channel Bonding
   signal rxChBondLevel : slv(2 downto 0) := "000";
   signal rxChBondIn    : slv(3 downto 0) := "0000";
   signal rxChBondOut   : slv(3 downto 0);

   -- PgpTx Signals
   signal gtTxResetDone   : sl;
   signal gtTxUserResetIn : sl;
   signal phyTxLanesOut   : EthTxPhyLaneOutArray(0 downto 0);
   signal phyTxReady      : sl;

   -- QPLL (GTPE2_COMMON) signals
   signal pllRefClk      : slv(1 downto 0);
   signal qPllOutClk     : slv(1 downto 0);   
   signal qPllOutRefClk  : slv(1 downto 0);
   signal qPllLock       : slv(1 downto 0);
   signal pllLockDetClk  : slv(1 downto 0);
   signal qPllRefClkLost : slv(1 downto 0);
   signal qPllReset      : slv(1 downto 0);
   signal gtQPllReset    : slv(1 downto 0);   

   -- General clocking signals
   signal ethClk125MHz     : sl;
   signal ethClk125MHzBufG : sl;
   signal ethClk125MHzRst  : sl;
   signal ethClk62MHz      : sl;
   signal ethClk62MHzBufG  : sl;
   signal ethClk62MHzRst   : sl;   
   signal stableClk125MHz     : sl;
   signal stableClk125MHzBufG : sl;
   signal stableClk125MHzRst  : sl;   
   signal mmcmLocked : sl;
   signal clkFbOut : sl;
   signal clkFbIn  : sl;
   signal txOutClk : sl;
   signal txOutClkBufG : sl;
   signal txMmcmResetOut : sl;
   signal txMmcmLockedIn : sl;
                                               
begin

   ethClk   <= ethClk125MHzBufG;
   ethClk62 <= ethClk62MHzBufG;
   --ethClk62 <= txOutClkBufG;
   txMmcmLockedIn <= mmcmLocked;

   U_TxOutClkBufG : BUFG port map ( I => txOutClk, O => txOutClkBufG );
   
   -- GT Reference Clock
   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => open,
         O     => stableClk125MHz);
   -- Put the stable clock on a global clock buffer
   U_StableClockBufG : BUFG
      port map (
         I => stableClk125MHz,
         O => stableClk125MHzBufG
      );
   -- Stable clock is used directly to generate resets. 
   -- It also routes to this MMCM to generate a fabric 125 MHz and 62.5 MHz.
   mmcm_adv_inst : MMCME2_ADV
   generic map(
      BANDWIDTH            => "LOW",
      CLKOUT4_CASCADE      => false,
      COMPENSATION         => "ZHOLD",
      STARTUP_WAIT         => false,
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT_F      => 16.0,
      CLKFBOUT_PHASE       => 0.000,
      CLKFBOUT_USE_FINE_PS => false,
      CLKOUT0_DIVIDE_F     => 8.0,
      CLKOUT0_PHASE        => 0.000,
      CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT0_USE_FINE_PS  => false,
      CLKOUT1_DIVIDE       => 16,
      CLKOUT1_PHASE        => 0.000,
      CLKOUT1_DUTY_CYCLE   => 0.500,
      CLKOUT1_USE_FINE_PS  => false,
      CLKOUT2_DIVIDE       => 6,
      CLKOUT2_PHASE        => 0.000,
      CLKOUT2_DUTY_CYCLE   => 0.500,
      CLKOUT2_USE_FINE_PS  => false,
      CLKOUT3_DIVIDE       => 4,
      CLKOUT3_PHASE        => 0.000,
      CLKOUT3_DUTY_CYCLE   => 0.500,
      CLKOUT3_USE_FINE_PS  => false,
      CLKOUT4_DIVIDE       => 5,
      CLKOUT4_PHASE        => 0.000,
      CLKOUT4_DUTY_CYCLE   => 0.500,
      CLKOUT4_USE_FINE_PS  => false,
      CLKIN1_PERIOD        => 16.0,
      REF_JITTER1          => 0.006)
   port map(
      -- Output clocks
      CLKFBOUT     => clkFbOut,
      CLKFBOUTB    => open,
      CLKOUT0      => ethClk125MHz,
      CLKOUT0B     => open,
      CLKOUT1      => ethClk62MHz,
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
--      CLKIN1       => stableClk125MHzBufG,
--      CLKIN1       => pgpRxRecClock,
      CLKIN1       => txOutClkBufG,
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
      LOCKED       => mmcmLocked,
      CLKINSTOPPED => open,
      CLKFBSTOPPED => open,
      PWRDWN       => '0',
      RST          => txMmcmResetOut);
--      RST          => stableClk125MHzRst);
   -- Feedback clock for the MMCM
   U_BUFG_FB : BUFG
      port map (
         I => clkFbOut,
         O => clkFbIn);       
   -- Put MMCM output clocks on global buffers
   U_BUFG_125 : BUFG
      port map (
         I  => ethClk125MHz,
         O  => ethClk125MHzBufG
      );      
--   U_BUFG_62 : BUFG
--      port map (
--         I  => ethClk62MHz,
--         O  => ethClk62MHzBufG
--      );
   ethClk62MHzBufG <= txOutClkBufG;

   ---------------------------------------------------------------------------
   -- Resets
   ---------------------------------------------------------------------------
   -- Generate stable reset signal
   U_PwrUpRst : entity work.PwrUpRst
      generic map (
         TPD_G         => TPD_G,
         SIM_SPEEDUP_G => toBoolean(SIM_GTRESET_SPEEDUP_G)
      )
      port map (
         clk    => stableClk125MHzBufG,
         rstOut => stableClk125MHzRst);      
   -- Synchronize the reset to the 125 MHz domain
   U_RstSync125 : entity work.RstSync
      port map (
         clk      => ethClk125MHzBufG,
         asyncRst => stableClk125MHzRst,
         syncRst  => ethClk125MHzRst
      );
   -- Synchronize the reset to the 62 MHz domain
      U_RstSync62 : entity work.RstSync
         port map (
            clk      => ethClk62MHzBufG,
            asyncRst => stableClk125MHzRst,
            syncRst  => ethClk62MHzRst
         );


   ---------------------------------------------------------------------------
   -- Gig Ethernet core
   ---------------------------------------------------------------------------
   U_GigEthLane : entity work.GigEthLane
      generic map (
         TPD_G                 => TPD_G,
         EN_AUTONEG_G          => EN_AUTONEG_G,
         UDP_PORT_G            => UDP_PORT_G,
         TX_REG_SIZE_G         => TX_REG_SIZE_G,
         EN_JUMBO_G            => EN_JUMBO_G,
         TX_JUMBO_SIZE_G       => TX_JUMBO_SIZE_G,
         -- Sim Generics
         SIM_RESET_SPEEDUP_G   => toBoolean(SIM_GTRESET_SPEEDUP_G),
         SIM_VERSION_G         => SIM_VERSION_G
      )
      port map (
         -- Clocking
         ethClk125MHz     => ethClk125MHzBufG,
         ethClk125MHzRst  => ethClk125MHzRst,
         ethClk62MHz      => ethClk62MHzBufG,
         ethClk62MHzRst   => ethClk62MHzRst,
         -- Link status signals
         ethRxLinkSync    => ethRxLinkSync,
         ethAutoNegDone   => ethAutoNegDone,
         -- GTX interface signals
         phyRxLaneIn      => phyRxLanesIn(0),
         phyRxLaneOut     => phyRxLanesOut(0),
         phyTxLaneOut     => phyTxLanesOut(0),
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
         macAddr          => macAddr
      );
   
   
   ---------------------------------------------------------------------------
   -- Generate the GTP PLL clocking
   ---------------------------------------------------------------------------
   -- PLL0 Port Mapping
   pllRefClk(0)     <= stableClk125MHz;
   pllLockDetClk(0) <= stableClk;
   qPllReset(0)     <= stableRst or gtQPllReset(0);

   -- PLL1 Port Mapping
   pllRefClk(1)     <= stableClk125MHz;
   pllLockDetClk(1) <= stableClk;
   qPllReset(1)     <= stableRst or gtQPllReset(1);

   Quad_Pll_Inst : entity work.Gtp7QuadPll
      generic map (
         PLL0_REFCLK_SEL_G    => "001",
         PLL0_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         PLL0_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         PLL0_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G,
         PLL1_REFCLK_SEL_G    => "001",
         PLL1_FBDIV_IN_G      => QPLL_FBDIV_IN_G,
         PLL1_FBDIV_45_IN_G   => QPLL_FBDIV_45_IN_G,
         PLL1_REFCLK_DIV_IN_G => QPLL_REFCLK_DIV_IN_G)         
      port map (
         qPllRefClk     => pllRefClk,
         qPllOutClk     => qPllOutClk,
         qPllOutRefClk  => qPllOutRefClk,
         qPllLock       => qPllLock,
         qPllLockDetClk => pllLockDetClk,
         qPllRefClkLost => qPllRefClkLost,
         qPllReset      => qPllReset);       
   
   ---------------------------------------------------------------------------
   -- Generate the GTP channels
   ---------------------------------------------------------------------------
   Gtp7Core_Inst : entity work.Gtp7Core
      generic map (
         TPD_G                    => TPD_G,
         SIM_GTRESET_SPEEDUP_G    => SIM_GTRESET_SPEEDUP_G,
         SIM_VERSION_G            => SIM_VERSION_G,
         STABLE_CLOCK_PERIOD_G    => STABLE_CLOCK_PERIOD_G,
         RXOUT_DIV_G              => RXOUT_DIV_G,
         TXOUT_DIV_G              => TXOUT_DIV_G,
         TX_PLL_G                 => TX_PLL_G,
         RX_PLL_G                 => RX_PLL_G,
         TX_EXT_DATA_WIDTH_G      => 16,
         TX_INT_DATA_WIDTH_G      => 20,
         TX_8B10B_EN_G            => true,
         RX_EXT_DATA_WIDTH_G      => 16,
         RX_INT_DATA_WIDTH_G      => 20,
         RX_8B10B_EN_G            => true,
         TX_BUF_EN_G              => true,
         TX_OUTCLK_SRC_G          => "PLLREFDV2",
         TX_DLY_BYPASS_G          => '1',
         TX_PHASE_ALIGN_G         => "AUTO",
         TX_BUF_ADDR_MODE_G       => "FAST",
         RX_BUF_EN_G              => true,
         RX_OUTCLK_SRC_G          => "PLLREFCLK",
         RX_USRCLK_SRC_G          => "RXOUTCLK",    -- Not 100% sure, doesn't really matter
         RX_DLY_BYPASS_G          => '1',
         RX_DDIEN_G               => '0',
         RX_BUF_ADDR_MODE_G       => "FAST",
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
         RX_CHAN_BOND_EN_G        => true,
         RX_CHAN_BOND_MASTER_G    => true,
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
         stableClkIn      => stableClk125MHzBufG,
         qPllRefClkIn     => qPllOutRefClk,
         qPllClkIn        => qPllOutClk,
         qPllLockIn       => qPllLock,
         qPllRefClkLostIn => qPllRefClkLost,
         qPllResetOut     => gtQPllReset,
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         rxOutClkOut      => pgpRxRecClock,
         rxUsrClkIn       => ethClk62MHzBufG,
         rxUsrClk2In      => ethClk62MHzBufG,
         rxUserRdyOut     => open,
         rxMmcmResetOut   => open,
         rxMmcmLockedIn   => '1',
         rxUserResetIn    => ethClk62MHzRst,
         rxResetDoneOut   => gtRxResetDone,
         rxDataValidIn    => '1',
         rxSlideIn        => '0',
         rxDataOut        => phyRxLanesIn(0).data,
         rxCharIsKOut     => phyRxLanesIn(0).dataK,
         rxDecErrOut      => phyRxLanesIn(0).decErr,
         rxDispErrOut     => phyRxLanesIn(0).dispErr,
         rxPolarityIn     => phyRxLanesOut(0).polarity,
         rxBufStatusOut   => open,
         rxChBondLevelIn  => rxChBondLevel,
         rxChBondIn       => rxChBondIn,
         rxChBondOut      => rxChBondOut,
         txOutClkOut      => txOutClk,
         txUsrClkIn       => ethClk62MHzBufG,
         txUsrClk2In      => ethClk62MHzBufG,
         txUserRdyOut     => open,
         txMmcmResetOut   => open,
         txMmcmLockedIn   => '1',
         txUserResetIn    => gtTxUserResetIn,
         txResetDoneOut   => gtTxResetDone,
         txDataIn         => phyTxLanesOut(0).data,
         txCharIsKIn      => phyTxLanesOut(0).dataK,
         txBufStatusOut   => open,
         loopbackIn       => loopback
      );

end rtl;
