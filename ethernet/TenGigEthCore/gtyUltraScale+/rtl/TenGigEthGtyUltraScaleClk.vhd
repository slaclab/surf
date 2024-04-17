-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 10GBASE-R Ethernet's Clock Module
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

library unisim;
use unisim.vcomponents.all;

entity TenGigEthGtyUltraScaleClk is
   generic (
      TPD_G             : time            := 1 ns;
      REF_CLK_FREQ_G    : real            := 156.25E+6;  -- Support 156.25MHz or 312.5MHz
      QPLL_REFCLK_SEL_G : slv(2 downto 0) := "001");
   port (
      -- MGT Clock Port (156.25 MHz)
      gtRefClk      : in  sl := '0';
      gtClkP        : in  sl := '1';
      gtClkN        : in  sl := '0';
      coreClk       : out sl;
      coreRst       : in  sl := '0';
      gtClk         : out sl;
      -- Quad PLL Ports
      qplllock      : out slv(1 downto 0);
      qplloutclk    : out slv(1 downto 0);
      qplloutrefclk : out slv(1 downto 0);
      qpllRst       : in  slv(1 downto 0));
end TenGigEthGtyUltraScaleClk;

architecture mapping of TenGigEthGtyUltraScaleClk is

   signal refClk     : sl;
   signal refClkCopy : sl;
   signal refClock   : sl;
   signal coreClock  : sl;
   signal qpllReset  : slv(1 downto 0);

begin

   gtClk <= refClock;

   IBUFDS_GTE3_Inst : IBUFDS_GTE4
      generic map (
         REFCLK_EN_TX_PATH  => '0',
         REFCLK_HROW_CK_SEL => "00",    -- 2'b00: ODIV2 = O
         REFCLK_ICNTL_RX    => "00")
      port map (
         I     => gtClkP,
         IB    => gtClkN,
         CEB   => '0',
         ODIV2 => refClkCopy,
         O     => refClk);

   BUFG_GT_Inst : BUFG_GT
      port map (
         I       => refClkCopy,
         CE      => '1',
         CEMASK  => '1',
         CLR     => '0',
         CLRMASK => '1',
         DIV     => "000",
         O       => coreClock);

   refClock <= gtRefClk when(QPLL_REFCLK_SEL_G = "111") else refClk;
   coreClk  <= gtRefClk when(QPLL_REFCLK_SEL_G = "111") else coreClock;

   qpllReset(0) <= qpllRst(0) or coreRst;
   qpllReset(1) <= qpllRst(1) or coreRst;

   GtyUltraScaleQuadPll_Inst : entity surf.GtyUltraScaleQuadPll
      generic map (
         -- Simulation Parameters
         TPD_G              => TPD_G,
         -- QPLL Configuration Parameters
         QPLL_CFG0_G        => (others => x"331C"),
         QPLL_CFG1_G        => (others => x"D038"),
         QPLL_CFG1_G3_G     => (others => x"D038"),
         QPLL_CFG2_G        => (others => x"0FC0"),
         QPLL_CFG2_G3_G     => (others => x"0FC0"),
         QPLL_CFG3_G        => (others => x"0120"),
         QPLL_CFG4_G        => (others => x"0002"),
         QPLL_CP_G          => (others => "0011111111"),
         QPLL_CP_G3_G       => (others => "0000001111"),
         QPLL_FBDIV_G       => (others => 66),
         QPLL_FBDIV_G3_G    => (others => 160),
         QPLL_INIT_CFG0_G   => (others => x"02B2"),
         QPLL_INIT_CFG1_G   => (others => x"00"),
         QPLL_LOCK_CFG_G    => (others => x"25E8"),
         QPLL_LOCK_CFG_G3_G => (others => x"25E8"),
         QPLL_LPF_G         => (others => "1000111111"),
         QPLL_LPF_G3_G      => (others => "0111010101"),
         QPLL_REFCLK_DIV_G  => (others => 1),
         QPLL_SDM_CFG0_G    => (others => x"0080"),
         QPLL_SDM_CFG1_G    => (others => x"0000"),
         QPLL_SDM_CFG2_G    => (others => x"0000"),
         -- Clock Selects
         QPLL_REFCLK_SEL_G  => (others => QPLL_REFCLK_SEL_G))
      port map (
         qPllRefClk(0)  => refClock,
         qPllRefClk(1)  => refClock,
         qPllOutClk     => qPllOutClk,
         qPllOutRefClk  => qPllOutRefClk,
         qPllLock       => qPllLock,
         qPllLockDetClk => "00",  -- IP Core ties this to GND (see note below)
         qPllReset      => qpllReset);

end mapping;
