-------------------------------------------------------------------------------
-- File       : TenGigEthGthUltraScaleClk.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-04-08
-- Last update: 2016-04-19
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

use work.StdRtlPkg.all;

library unisim;
use unisim.vcomponents.all;

entity TenGigEthGthUltraScaleClk is
   generic (
      TPD_G             : time            := 1 ns;
      REF_CLK_FREQ_G    : real            := 156.25E+6;  -- Support 156.25MHz or 312.5MHz   
      QPLL_REFCLK_SEL_G : slv(2 downto 0) := "001");
   port (
      -- MGT Clock Port (156.25 MHz or 312.5 MHz)
      gtRefClk      : in  sl := '0';
      gtClkP        : in  sl := '1';
      gtClkN        : in  sl := '0';
      coreClk       : out sl;
      coreRst       : in  sl := '0';
      gtClk         : out sl;
      -- Quad PLL Ports
      qplllock      : out sl;
      qplloutclk    : out sl;
      qplloutrefclk : out sl;
      qpllRst       : in  sl);      
end TenGigEthGthUltraScaleClk;

architecture mapping of TenGigEthGthUltraScaleClk is

   constant DIV_C : slv(2 downto 0) := ite((REF_CLK_FREQ_G = 156.25E+6), "000", "001");

   signal refClk     : sl;
   signal refClkCopy : sl;
   signal refClock   : sl;
   signal coreClock  : sl;
   signal qpllReset  : sl;

begin
   
   gtClk <= refClock;

   IBUFDS_GTE3_Inst : IBUFDS_GTE3
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
         DIV     => DIV_C,
         O       => coreClock);

   refClock  <= gtRefClk when(QPLL_REFCLK_SEL_G = "111") else refClk;
   coreClk   <= gtRefClk when(QPLL_REFCLK_SEL_G = "111") else coreClock;
   qpllReset <= qpllRst or coreRst;

   GEN_156p25MHz : if (REF_CLK_FREQ_G = 156.25E+6) generate
      GthUltraScaleQuadPll_Inst : entity work.GthUltraScaleQuadPll
         generic map (
            -- Simulation Parameters
            TPD_G               => TPD_G,
            SIM_RESET_SPEEDUP_G => "FALSE",
            SIM_VERSION_G       => 2,
            -- QPLL Configuration Parameters
            QPLL_CFG0_G         => (others => x"301C"),
            QPLL_CFG1_G         => (others => x"0018"),
            QPLL_CFG1_G3_G      => (others => x"0018"),
            QPLL_CFG2_G         => (others => x"0048"),
            QPLL_CFG2_G3_G      => (others => x"0048"),
            QPLL_CFG3_G         => (others => x"0120"),
            QPLL_CFG4_G         => (others => x"0009"),
            QPLL_CP_G           => (others => "0000011111"),
            QPLL_CP_G3_G        => (others => "1111111111"),
            QPLL_FBDIV_G        => (others => 66),
            QPLL_FBDIV_G3_G     => (others => 80),
            QPLL_INIT_CFG0_G    => (others => x"0000"),
            QPLL_INIT_CFG1_G    => (others => x"00"),
            QPLL_LOCK_CFG_G     => (others => x"25E8"),
            QPLL_LOCK_CFG_G3_G  => (others => x"25E8"),
            QPLL_LPF_G          => (others => "1111111111"),
            QPLL_LPF_G3_G       => (others => "0000010101"),
            QPLL_REFCLK_DIV_G   => (others => 1),
            QPLL_SDM_CFG0_G     => (others => x"0000"),
            QPLL_SDM_CFG1_G     => (others => x"0000"),
            QPLL_SDM_CFG2_G     => (others => x"0000"),
            -- Clock Selects
            QPLL_REFCLK_SEL_G   => (others => QPLL_REFCLK_SEL_G))
         port map (
            qPllRefClk(0)     => refClock,
            qPllRefClk(1)     => '0',
            qPllOutClk(0)     => qPllOutClk,
            qPllOutClk(1)     => open,
            qPllOutRefClk(0)  => qPllOutRefClk,
            qPllOutRefClk(1)  => open,
            qPllLock(0)       => qPllLock,
            qPllLock(1)       => open,
            qPllLockDetClk(0) => '0',   -- IP Core ties this to GND (see note below) 
            qPllLockDetClk(1) => '0',   -- IP Core ties this to GND (see note below) 
            qPllPowerDown(0)  => '0',
            qPllPowerDown(1)  => '1',
            qPllReset(0)      => qpllReset,
            qPllReset(1)      => '1'); 
   end generate;
   GEN_312p5MHz : if (REF_CLK_FREQ_G = 312.50E+6) generate
      GthUltraScaleQuadPll_Inst : entity work.GthUltraScaleQuadPll
         generic map (
            -- Simulation Parameters
            TPD_G               => TPD_G,
            SIM_RESET_SPEEDUP_G => "FALSE",
            SIM_VERSION_G       => 2,
            -- QPLL Configuration Parameters
            QPLL_CFG0_G         => (others => x"301C"),
            QPLL_CFG1_G         => (others => x"0018"),
            QPLL_CFG1_G3_G      => (others => x"0018"),
            QPLL_CFG2_G         => (others => x"0048"),
            QPLL_CFG2_G3_G      => (others => x"0048"),
            QPLL_CFG3_G         => (others => x"0120"),
            QPLL_CFG4_G         => (others => x"0009"),
            QPLL_CP_G           => (others => "0000011111"),
            QPLL_CP_G3_G        => (others => "1111111111"),
            QPLL_FBDIV_G        => (others => 66),
            QPLL_FBDIV_G3_G     => (others => 80),
            QPLL_INIT_CFG0_G    => (others => x"0000"),
            QPLL_INIT_CFG1_G    => (others => x"00"),
            QPLL_LOCK_CFG_G     => (others => x"25E8"),
            QPLL_LOCK_CFG_G3_G  => (others => x"25E8"),
            QPLL_LPF_G          => (others => "1111111111"),
            QPLL_LPF_G3_G       => (others => "0000010101"),
            QPLL_REFCLK_DIV_G   => (others => 2),
            QPLL_SDM_CFG0_G     => (others => x"0000"),
            QPLL_SDM_CFG1_G     => (others => x"0000"),
            QPLL_SDM_CFG2_G     => (others => x"0000"),
            -- Clock Selects
            QPLL_REFCLK_SEL_G   => (others => QPLL_REFCLK_SEL_G))
         port map (
            qPllRefClk(0)     => refClock,
            qPllRefClk(1)     => '0',
            qPllOutClk(0)     => qPllOutClk,
            qPllOutClk(1)     => open,
            qPllOutRefClk(0)  => qPllOutRefClk,
            qPllOutRefClk(1)  => open,
            qPllLock(0)       => qPllLock,
            qPllLock(1)       => open,
            qPllLockDetClk(0) => '0',   -- IP Core ties this to GND (see note below) 
            qPllLockDetClk(1) => '0',   -- IP Core ties this to GND (see note below) 
            qPllPowerDown(0)  => '0',
            qPllPowerDown(1)  => '1',
            qPllReset(0)      => qpllReset,
            qPllReset(1)      => '1');          
   end generate;
   ---------------------------------------------------------------------------------------------
   -- Note: GTXE3_COMMON pin GTHE3_COMMON_Inst.QPLLLOCKDETCLK[1:0] cannot be driven by a clock 
   --       derived from the same clock used as the reference clock for the QPLL, including 
   --       TXOUTCLK*, RXOUTCLK*, the output from the IBUFDS_GTE2 providing the reference clock, 
   --       and any --       buffered or multiplied/divided versions of these clock outputs. 
   --       Please see UG576 for more information. Source, through a clock buffer, is the same 
   --       as the GT cell reference clock.
   ---------------------------------------------------------------------------------------------
   
end mapping;
