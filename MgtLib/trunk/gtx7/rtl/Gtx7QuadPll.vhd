-------------------------------------------------------------------------------
-- Title      : 
-------------------------------------------------------------------------------
-- File       : Gtx7QuadPll.vhd
-- Author     : Benjamin Reese  <bareese@slac.stanford.edu>
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2013-06-06
-- Last update: 2014-10-27
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2013 SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.StdRtlPkg.all;

library UNISIM;
use UNISIM.VCOMPONENTS.all;

entity Gtx7QuadPll is
   
   generic (
      TPD_G               : time       := 1 ns;
      SIM_RESET_SPEEDUP_G : string     := "TRUE";
      SIM_VERSION_G       : string     := "4.0";
      QPLL_CFG_G          : bit_vector := x"0680181";  -- QPLL_CFG_G[6] selects the QPLL frequency band: 0 = upper band, 1 = lower band
      QPLL_REFCLK_SEL_G   : bit_vector := "001";
      QPLL_FBDIV_G        : bit_vector := "0100100000";
      QPLL_FBDIV_RATIO_G  : bit        := '1';
      QPLL_REFCLK_DIV_G   : integer    := 1);

   port (
      qPllRefClk     : in  sl;
      qPllOutClk     : out sl;
      qPllOutRefClk  : out sl;
      qPllLock       : out sl;
      qPllLockDetClk : in  sl;          -- Lock detect clock
      qPllRefClkLost : out sl;
      qPllPowerDown  : in  sl := '0';
      qPllReset      : in  sl);

end entity Gtx7QuadPll;

architecture rtl of Gtx7QuadPll is

   signal gtRefClk0      : sl;
   signal gtRefClk1      : sl;
   signal gtNorthRefClk0 : sl;
   signal gtNorthRefClk1 : sl;
   signal gtSouthRefClk0 : sl;
   signal gtSouthRefClk1 : sl;
   signal gtGRefClk      : sl;

begin


   --------------------------------------------------------------------------------------------------
   -- QPLL clock select. Only ever use 1 clock to drive qpll. Never switch clocks.
   --------------------------------------------------------------------------------------------------
   gtRefClk0      <= qpllRefClk when QPLL_REFCLK_SEL_G = "001" else '0';
   gtRefClk1      <= qpllRefClk when QPLL_REFCLK_SEL_G = "010" else '0';
   gtNorthRefClk0 <= qpllRefClk when QPLL_REFCLK_SEL_G = "011" else '0';
   gtNorthRefClk1 <= qpllRefClk when QPLL_REFCLK_SEL_G = "100" else '0';
   gtSouthRefClk0 <= qpllRefClk when QPLL_REFCLK_SEL_G = "101" else '0';
   gtSouthRefClk1 <= qpllRefClk when QPLL_REFCLK_SEL_G = "110" else '0';
   gtGRefClk      <= qpllRefClk when QPLL_REFCLK_SEL_G = "111" else '0';

   gtxe2_common_0_i : GTXE2_COMMON
      generic map (
         -- Simulation attributes
         SIM_RESET_SPEEDUP  => "TRUE",
         SIM_QPLLREFCLK_SEL => QPLL_REFCLK_SEL_G,
         SIM_VERSION        => "4.0",

         ------------------COMMON BLOCK Attributes---------------
         BIAS_CFG                 => (x"0000040000001000"),
         COMMON_CFG               => (x"00000000"),
         QPLL_CFG                 => QPLL_CFG_G,
         QPLL_CLKOUT_CFG          => ("0000"),
         QPLL_COARSE_FREQ_OVRD    => ("010000"),
         QPLL_COARSE_FREQ_OVRD_EN => ('0'),
         QPLL_CP                  => ("0000011111"),
         QPLL_CP_MONITOR_EN       => ('0'),
         QPLL_DMONITOR_SEL        => ('0'),
         QPLL_FBDIV               => QPLL_FBDIV_G,
         QPLL_FBDIV_MONITOR_EN    => ('0'),
         QPLL_FBDIV_RATIO         => QPLL_FBDIV_RATIO_G,
         QPLL_INIT_CFG            => (x"000006"),
         QPLL_LOCK_CFG            => (x"21E8"),
         QPLL_LPF                 => ("1111"),
         QPLL_REFCLK_DIV          => QPLL_REFCLK_DIV_G
         )
      port map (
         ------------- Common Block  - Dynamic Reconfiguration Port (DRP) -----------
         DRPADDR          => (others => '0'),
         DRPCLK           => '0',
         DRPDI            => (others => '0'),
         DRPDO            => open,
         DRPEN            => '0',
         DRPRDY           => open,
         DRPWE            => '0',
         ---------------------- Common Block  - Ref Clock Ports ---------------------
         GTGREFCLK        => gtGRefClk,
         GTNORTHREFCLK0   => gtNorthRefClk0,
         GTNORTHREFCLK1   => gtNorthRefClk1,
         GTREFCLK0        => gtRefClk0,
         GTREFCLK1        => gtRefClk1,
         GTSOUTHREFCLK0   => gtSouthRefClk0,
         GTSOUTHREFCLK1   => gtSouthRefClk1,
         ------------------------- Common Block -  QPLL Ports -----------------------
         QPLLDMONITOR     => open,
         ----------------------- Common Block - Clocking Ports ----------------------
         QPLLOUTCLK       => qPllOutClk,
         QPLLOUTREFCLK    => qPllOutRefClk,
         REFCLKOUTMONITOR => open,
         ------------------------- Common Block - QPLL Ports ------------------------
         QPLLFBCLKLOST    => open,
         QPLLLOCK         => qPllLock,
         QPLLLOCKDETCLK   => qPllLockDetClk,
         QPLLLOCKEN       => '1',
         QPLLOUTRESET     => '0',
         QPLLPD           => qPllPowerDown,
         QPLLREFCLKLOST   => qPllRefClkLost,
         QPLLREFCLKSEL    => to_stdlogicvector(QPLL_REFCLK_SEL_G),
         QPLLRESET        => qPllReset,
         QPLLRSVD1        => "0000000000000000",
         QPLLRSVD2        => "11111",
         --------------------------------- QPLL Ports -------------------------------
         BGBYPASSB        => '1',
         BGMONITORENB     => '1',
         BGPDB            => '1',
         BGRCALOVRD       => "00000",
         PMARSVD          => "00000000",
         RCALENB          => '1'

         );

end architecture rtl;
