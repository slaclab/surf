-------------------------------------------------------------------------------
-- Title      : Example Code
-------------------------------------------------------------------------------
-- File       : EthGtx7Wrapper.vhd
-- Author     : Larry Ruckman  <ruckman@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-01-30
-- Last update: 2015-01-30
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2015 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

use work.StdRtlPkg.all;
use work.AxiStreamPkg.all;
use work.GigEthPkg.all;
use work.EthClientPackage.all;

library unisim;
use unisim.vcomponents.all;

entity EthGtx7Wrapper is
   generic (
      TPD_G              : time                    := 1 ns;
      -- Ethernet Configurations
      EN_AUTONEG_G       : boolean                 := true;
      UDP_PORT_G         : natural                 := 8192;
      TX_REG_SIZE_G      : slv(11 downto 0)        := x"168";  -- Default: 360 x 32-bit words = 1.44kB
      EN_JUMBO_G         : boolean                 := false;
      TX_JUMBO_SIZE_G    : slv(11 downto 0)        := x"4E2";  -- Default: 1250 x 32-bit words = 5kB    
      -- MMCM Configurations (Defaults: gtClkP = 125 MHz Configuration)
      CLKIN_PERIOD_G     : real                    := 16.0;-- gtClkP/2
      DIVCLK_DIVIDE_G    : natural range 1 to 106  := 1;
      CLKFBOUT_MULT_F_G  : real range 1.0 to 64.0  := 16.0;
      CLKOUT0_DIVIDE_F_G : real range 1.0 to 128.0 := 8.0;
      -- CPLL Settings (Defaults: gtClkP = 125 MHz Configuration)
      CPLL_REFCLK_SEL_G  : bit_vector              := "001";
      CPLL_FBDIV_G       : natural                 := 4;
      CPLL_FBDIV_45_G    : natural                 := 5;
      CPLL_REFCLK_DIV_G  : natural                 := 1;
      -- MGT Configurations (Defaults: gtClkP = 125 MHz Configuration)
      RXOUT_DIV_G        : natural                 := 4;
      TXOUT_DIV_G        : natural                 := 4;
      RX_CLK25_DIV_G     : natural                 := 5;
      TX_CLK25_DIV_G     : natural                 := 5;
      RX_OS_CFG_G        : bit_vector              := "0000010000000";      
      RXCDR_CFG_G        : bit_vector              := x"03000023ff40080020"; 
      RXDFEXYDEN_G       : sl                      := '1';   
      RX_DFE_KL_CFG2_G   : bit_vector              := x"301148AC";          
      -- Configure Number of VC Lanes
      NUM_VC_EN_G        : natural range 1 to 4    := 4);      
   port (
      -- Manual Reset
      extRst         : in  sl;
      -- Clocks and Reset
      ethClk         : out sl;
      ethRst         : out sl;
      stableClk      : out sl;      
      -- Ethernet Status
      ethRxLinkSync  : out sl;
      ethAutoNegDone : out sl;
      -- MAC address and IP address
      macAddr        : in  MacAddrType;
      ipAddr         : in  IPAddrType;
      -- Frame TX Interface
      ethTxMasters   : in  AxiStreamMasterArray(3 downto 0);
      ethTxSlaves    : out AxiStreamSlaveArray(3 downto 0);
      -- Frame RX Interface
      ethRxMasters   : out AxiStreamMasterArray(3 downto 0);
      ethRxCtrl      : in  AxiStreamCtrlArray(3 downto 0);
      -- GT Pins
      gtClkP         : in  sl;
      gtClkN         : in  sl;
      gtTxP          : out sl;
      gtTxN          : out sl;
      gtRxP          : in  sl;
      gtRxN          : in  sl);  
end EthGtx7Wrapper;

architecture mapping of EthGtx7Wrapper is

   signal refClk     : sl;
   signal refClkDiv2 : sl;
   signal stableClock  : sl;
   signal extRstSync : sl;
   
   signal ethClk125MHz    : sl;
   signal ethClk125MHzRst : sl;
   signal ethClk62MHz     : sl;
   signal ethClk62MHzRst  : sl;

begin

   ethClk <= ethClk125MHz;
   ethRst <= ethClk125MHzRst;
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
         NUM_CLOCKS_G       => 2,
         -- MMCM attributes
         BANDWIDTH_G        => "OPTIMIZED",
         CLKIN_PERIOD_G     => CLKIN_PERIOD_G,
         DIVCLK_DIVIDE_G    => DIVCLK_DIVIDE_G,
         CLKFBOUT_MULT_F_G  => CLKFBOUT_MULT_F_G,
         CLKOUT0_DIVIDE_F_G => CLKOUT0_DIVIDE_F_G,
         CLKOUT1_DIVIDE_G   => getTimeRatio(CLKOUT0_DIVIDE_F_G, 2.0))
      port map(
         clkIn     => stableClock,
         rstIn     => extRstSync,
         clkOut(0) => ethClk125MHz,
         clkOut(1) => ethClk62MHz,
         rstOut(0) => ethClk125MHzRst,
         rstOut(1) => ethClk62MHzRst);                 

   EthGtx7_Inst : entity work.EthGtx7
      generic map (
         TPD_G             => TPD_G,
         -- Ethernet Configurations
         EN_AUTONEG_G      => EN_AUTONEG_G,
         UDP_PORT_G        => UDP_PORT_G,
         TX_REG_SIZE_G     => TX_REG_SIZE_G,
         EN_JUMBO_G        => EN_JUMBO_G,
         TX_JUMBO_SIZE_G   => TX_JUMBO_SIZE_G,
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
         NUM_VC_EN_G       => NUM_VC_EN_G) 
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
         -- Gt Serial IO
         gtTxP            => gtTxP,
         gtTxN            => gtTxN,
         gtRxP            => gtRxP,
         gtRxN            => gtRxN,
         -- Clocking and Resets
         ethClk62MHz      => ethClk62MHz,
         ethClk62MHzRst   => ethClk62MHzRst,
         ethClk125MHz     => ethClk125MHz,
         ethClk125MHzRst  => ethClk125MHzRst,
         -- Link status signals
         ethRxLinkSync    => ethRxLinkSync,
         ethAutoNegDone   => ethAutoNegDone,
         -- MAC address and IP address
         ipAddr           => ipAddr,
         macAddr          => macAddr,
         -- Frame Transmit Interface - Array of 4 VCs (ethClk125MHz domain)
         ethTxMasters     => ethTxMasters,
         ethTxSlaves      => ethTxSlaves,
         -- Frame Receive Interface - Array of 4 VCs (ethClk125MHz domain)
         ethRxMasters     => ethRxMasters,
         ethRxCtrl        => ethRxCtrl);

end mapping;
