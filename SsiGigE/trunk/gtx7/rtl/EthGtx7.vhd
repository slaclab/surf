-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : EthGtx7.vhd
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

entity EthGtx7 is
   generic (
      TPD_G             : time       := 1 ns;
      ----------------------------------------------------------------------------------------------
      -- GT Settings
      ----------------------------------------------------------------------------------------------
      -- Sim Generics
      SIM_GTRESET_SPEEDUP_G : string     := "FALSE";
      SIM_VERSION_G         : string     := "4.0";
      STABLE_CLOCK_PERIOD_G : real       := 8.0E-9;  --units of seconds
      -- CPLL Settings
      CPLL_REFCLK_SEL_G     : bit_vector := "001";
      --      CPLL_REFCLK_SEL_G     : bit_vector := "010";
      CPLL_FBDIV_G          : integer    := 4;
      CPLL_FBDIV_45_G       : integer    := 5;
      CPLL_REFCLK_DIV_G     : integer    := 2;
      RXOUT_DIV_G           : integer    := 2;
      TXOUT_DIV_G           : integer    := 2;
      RX_CLK25_DIV_G        : integer    := 5;
      TX_CLK25_DIV_G        : integer    := 5;

      RX_OS_CFG_G  : bit_vector := "0000010000000";        -- Set by wizard
      RXCDR_CFG_G  : bit_vector := x"03000023ff40200020";  -- Set by wizard
      RXDFEXYDEN_G : sl         := '0';                    -- Set by wizard

      -- RX Equalizer Attributes
      RX_DFE_KL_CFG2_G : bit_vector := x"3010D90C";  -- Set by wizard
      -- Configure PLL sources
      TX_PLL_G         : string     := "CPLL";
      RX_PLL_G         : string     := "CPLL";

      -- Configure Number of Lanes (only 1 allowed for ethernet)
      LANE_CNT_G        : integer range 1 to 1 := 1;
      ----------------------------------------------------------------------------------------------
      -- PGP Settings
      ----------------------------------------------------------------------------------------------
      PGP_RX_ENABLE_G   : boolean              := true;
      PGP_TX_ENABLE_G   : boolean              := true;
      PAYLOAD_CNT_TOP_G : integer              := 7;        -- Top bit for payload counter
      VC_INTERLEAVE_G   : integer              := 1;        -- Interleave Frames
      NUM_VC_EN_G       : integer range 1 to 4 := 4
   );
   port (
      stableRst        : in sl;
      -- Gt Serial IO
      gtTxP            : out slv((LANE_CNT_G-1) downto 0);  -- GT Serial Transmit Positive
      gtTxN            : out slv((LANE_CNT_G-1) downto 0);  -- GT Serial Transmit Negative
      gtRxP            : in  slv((LANE_CNT_G-1) downto 0);  -- GT Serial Receive Positive
      gtRxN            : in  slv((LANE_CNT_G-1) downto 0);  -- GT Serial Receive Negative
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
end EthGtx7;

-- Define architecture
architecture rtl of EthGtx7 is

   --------------------------------------------------------------------------------------------------
   -- Constants
   --------------------------------------------------------------------------------------------------
   signal gtQPllResets : slv((LANE_CNT_G-1) downto 0);

   -- PgpRx Signals
   signal pgpRxMmcmResets : slv((LANE_CNT_G-1) downto 0);
   signal pgpRxRecClock   : slv((LANE_CNT_G-1) downto 0);
   signal gtRxResetDone   : slv((LANE_CNT_G-1) downto 0);
   signal gtRxUserReset   : sl;
   signal gtRxUserResetIn : sl;
   signal phyRxLanesIn    : EthRxPhyLaneInArray((LANE_CNT_G-1) downto 0);
   signal phyRxLanesOut   : EthRxPhyLaneOutArray((LANE_CNT_G-1) downto 0);
   signal phyRxInit       : sl;

   -- Rx Channel Bonding
   signal rxChBondLevel : slv(2 downto 0);
   signal rxChBondIn    : Slv5Array(LANE_CNT_G-1 downto 0);
   signal rxChBondOut   : Slv5Array(LANE_CNT_G-1 downto 0);

   -- PgpTx Signals
   signal pgpTxMmcmResets : slv((LANE_CNT_G-1) downto 0);
   signal gtTxResetDone   : slv((LANE_CNT_G-1) downto 0);
   signal gtTxUserResetIn : sl;
   signal phyTxLanesOut   : EthTxPhyLaneOutArray((LANE_CNT_G-1) downto 0);
   signal phyTxReady      : sl;

   signal gtCPllRefClk    : sl;
   signal gtCPllClk       : sl;
   signal gtCPllLock      : sl;

   signal ethClk125MHz     : sl;
   signal ethClk125MHzBufG : sl;
   signal ethClk125MHzRst  : sl;
   signal ethClk62MHz      : sl;
   signal ethClk62MHzRaw   : sl;
   signal ethClk62MHzRst   : sl;      

   signal clkFbOut : sl;
   signal clkFbIn  : sl;
                                               
begin

   ethClk <= ethClk125MHzBufG;
   ethClk62 <= ethClk62MHz;
   
   -- GT Reference Clock
   IBUFDS_GTE2_Inst : IBUFDS_GTE2
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => open,
         O     => gtCPllClk);

   G_gtCpllRefClkFabric : if CPLL_REFCLK_SEL_G = "111" generate
      gtCpllRefClk <= gtFabricClk;
   end generate;
   G_gtCpllRefClkStandard : if CPLL_REFCLK_SEL_G /= "111" generate
      gtCpllRefClk <= gtCPllClk;
   end generate;   
         
   -- U_BUFG125 : BUFG
      -- port map (
         -- I  => ethClk125MHz,
         -- O  => ethClk125MHzBufG
      -- ); 
      
   -- Generate 125 MHz from the 62.5 MHz
   mmcm_adv_inst : MMCME2_ADV
   generic map(
      BANDWIDTH            => "LOW",
      CLKOUT4_CASCADE      => false,
      COMPENSATION         => "ZHOLD",
      STARTUP_WAIT         => false,
      DIVCLK_DIVIDE        => 1,
      CLKFBOUT_MULT_F      => 20.0,
      CLKFBOUT_PHASE       => 0.000,
      CLKFBOUT_USE_FINE_PS => false,
      CLKOUT0_DIVIDE_F     => 10.0,
      CLKOUT0_PHASE        => 0.000,
      CLKOUT0_DUTY_CYCLE   => 0.500,
      CLKOUT0_USE_FINE_PS  => false,
      CLKOUT1_DIVIDE       => 4,
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
      CLKOUT1      => open,
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
      CLKIN1       => ethClk62MHz,
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
      LOCKED       => open,
      CLKINSTOPPED => open,
      CLKFBSTOPPED => open,
      PWRDWN       => '0',
      RST          => ethClk62MHzRst);

   BUFH_1 : BUFG
      port map (
         I => clkFbOut,
         O => clkFbIn);       
   U_BUFG_125 : BUFG
      port map (
         I  => ethClk125MHz,
         O  => ethClk125MHzBufG
      );

      
   U_BUFG : BUFG
      port map (
         I  => ethClk62MHzRaw,
         O  => ethClk62MHz
      );
         
   -- Generate stable reset signal
   U_PwrUpRst : entity work.PwrUpRst
      generic map (
         TPD_G         => TPD_G,
         SIM_SPEEDUP_G => toBoolean(SIM_GTRESET_SPEEDUP_G)
      )
      port map (
         clk    => ethClk62MHz,
         rstOut => ethClk62MHzRst);   
   
   -- Synchronize the reset to the 125 MHz domain
   U_RstSync : entity work.RstSync
      port map (
         clk      => ethClk125MHzBufG,
         asyncRst => ethClk62MHzRst,
         syncRst  => ethClk125MHzRst
      );

   --------------------------------------------------------------------------------------------------
   -- Gig Ethernet core
   --------------------------------------------------------------------------------------------------   
   U_GigEthLane : entity work.GigEthLane
      generic map (
         TPD_G                 => TPD_G,
         -- Sim Generics
         SIM_RESET_SPEEDUP_G   => toBoolean(SIM_GTRESET_SPEEDUP_G),
         SIM_VERSION_G         => SIM_VERSION_G
      )
      port map (
         -- Clocking
         ethClk125MHz     => ethClk125MHzBufG,
         ethClk125MHzRst  => ethClk125MHzRst,
         ethClk62MHz      => ethClk62MHz,
         ethClk62MHzRst   => ethClk62MHzRst,
         -- Link status signals
         ethRxLinkSync    => ethRxLinkSync,
         ethAutoNegDone   => ethAutoNegDone,
         -- GTX interface signals
         phyRxLaneIn      => phyRxLanesIn(0),
         phyRxLaneOut     => phyRxLanesOut(0),
         phyTxLaneOut     => phyTxLanesOut(0),
         phyRxReady       => gtRxResetDone(0),
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
   
   --------------------------------------------------------------------------------------------------
   -- Generate the GTX channels
   --------------------------------------------------------------------------------------------------
   GTX7_CORE_GEN : for i in (LANE_CNT_G-1) downto 0 generate
      Bond_Master : if (i = 0) generate
         rxChBondIn(i) <= "00000";
      end generate Bond_Master;

      Gtx7Core_Inst : entity work.Gtx7Core
         generic map (
            TPD_G                    => TPD_G,
            SIM_GTRESET_SPEEDUP_G    => SIM_GTRESET_SPEEDUP_G,
            SIM_VERSION_G            => SIM_VERSION_G,
            STABLE_CLOCK_PERIOD_G    => STABLE_CLOCK_PERIOD_G,
            CPLL_REFCLK_SEL_G        => CPLL_REFCLK_SEL_G,
            CPLL_FBDIV_G             => CPLL_FBDIV_G,
            CPLL_FBDIV_45_G          => CPLL_FBDIV_45_G,
            CPLL_REFCLK_DIV_G        => CPLL_REFCLK_DIV_G,
            RXOUT_DIV_G              => RXOUT_DIV_G,
            TXOUT_DIV_G              => TXOUT_DIV_G,
            RX_CLK25_DIV_G           => RX_CLK25_DIV_G,
            TX_CLK25_DIV_G           => TX_CLK25_DIV_G,
            PMA_RSV_G                => x"00018480",
            TX_PLL_G                 => TX_PLL_G,
            RX_PLL_G                 => RX_PLL_G,
            TX_EXT_DATA_WIDTH_G      => 16,
            TX_INT_DATA_WIDTH_G      => 20,
            TX_8B10B_EN_G            => true,
            RX_EXT_DATA_WIDTH_G      => 16,
            RX_INT_DATA_WIDTH_G      => 20,
            RX_8B10B_EN_G            => true,
            TX_BUF_EN_G              => true,
--            TX_OUTCLK_SRC_G          => "OUTCLKPMA",
            TX_OUTCLK_SRC_G          => "PLLDV2CLK",
            TX_DLY_BYPASS_G          => '1',
            TX_PHASE_ALIGN_G         => "NONE",
            TX_BUF_ADDR_MODE_G       => "FULL",
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
            RX_CHAN_BOND_EN_G        => true,
            RX_CHAN_BOND_MASTER_G    => (i = 0),
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
            FTS_LANE_DESKEW_EN_G     => "FALSE",       -- Default
            RX_OS_CFG_G              => RX_OS_CFG_G,
            RXCDR_CFG_G              => RXCDR_CFG_G,
            RXDFEXYDEN_G             => RXDFEXYDEN_G,
            RX_DFE_KL_CFG2_G         => RX_DFE_KL_CFG2_G)
         port map (
            stableClkIn      => stableClk,
            cPllRefClkIn     => gtCPllRefClk,
            cPllLockOut      => gtCPllLock,
            -- qPllRefClkIn     => gtQPllRefClk,
            -- qPllClkIn        => gtQPllClk,
            -- qPllLockIn       => gtQPllLock,
            -- qPllRefClkLostIn => gtQPllRefClkLost,
            -- qPllResetOut     => gtQPllResets(i),
            gtTxP            => gtTxP(i),
            gtTxN            => gtTxN(i),
            gtRxP            => gtRxP(i),
            gtRxN            => gtRxN(i),
            rxOutClkOut      => pgpRxRecClock(i),
            rxUsrClkIn       => ethClk62MHz,
            rxUsrClk2In      => ethClk62MHz,
            rxUserRdyOut     => open,
            rxMmcmResetOut   => pgpRxMmcmResets(i),
            rxMmcmLockedIn   => '1',
            rxUserResetIn    => ethClk62MHzRst,
            rxResetDoneOut   => gtRxResetDone(i),
            rxDataValidIn    => '1',
            rxSlideIn        => '0',
            rxDataOut        => phyRxLanesIn(i).data,
            rxCharIsKOut     => phyRxLanesIn(i).dataK,
            rxDecErrOut      => phyRxLanesIn(i).decErr,
            rxDispErrOut     => phyRxLanesIn(i).dispErr,
            rxPolarityIn     => phyRxLanesOut(i).polarity,
            rxBufStatusOut   => open,
            rxChBondLevelIn  => slv(to_unsigned((LANE_CNT_G-1-i), 3)),
            rxChBondIn       => rxChBondIn(i),
            rxChBondOut      => rxChBondOut(i),
            txOutClkOut      => ethClk62MHzRaw,
            txUsrClkIn       => ethClk62MHz,
            txUsrClk2In      => ethClk62MHz,
            txUserRdyOut     => open,
            txMmcmResetOut   => pgpTxMmcmResets(i),
            txMmcmLockedIn   => '1',
            txUserResetIn    => ethClk62MHzRst,
            txResetDoneOut   => gtTxResetDone(i),
            txDataIn         => phyTxLanesOut(i).data,
            txCharIsKIn      => phyTxLanesOut(i).dataK,
            txBufStatusOut   => open,
            loopbackIn       => loopback);
   end generate GTX7_CORE_GEN;

   
end rtl;
