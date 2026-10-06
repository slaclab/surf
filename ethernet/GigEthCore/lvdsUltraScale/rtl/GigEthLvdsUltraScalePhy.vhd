-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: LVDS SGMII PHY with external GMII MAC; clocks and rate enable supplied by PCS.
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

entity GigEthLvdsUltraScalePhy is
   port (
      coreRst         : in  sl;
      sigDet          : in  sl := '1';
      speed_is_10_100 : in  sl := '0';
      speed_is_100    : in  sl := '0';
      coreConfig      : in  slv(4 downto 0);
      coreStatus      : out slv(15 downto 0);
      sysClk125       : out sl;
      sysRst125       : out sl;
      sysClkEn        : out sl;
      gmiiTxd         : in  slv(7 downto 0);
      gmiiTxEn        : in  sl;
      gmiiTxEr        : in  sl;
      gmiiRxd         : out slv(7 downto 0);
      gmiiRxDv        : out sl;
      gmiiRxEr        : out sl;
      sgmiiClkP       : in  sl;
      sgmiiClkN       : in  sl;
      sgmiiRxP        : in  sl;
      sgmiiRxN        : in  sl;
      sgmiiTxP        : out sl;
      sgmiiTxN        : out sl);
end entity GigEthLvdsUltraScalePhy;

architecture rtl of GigEthLvdsUltraScalePhy is

   component GigEthLvdsUltraScaleCore
      port (
         txn                  : out std_logic;
         txp                  : out std_logic;
         rxn                  : in  std_logic;
         rxp                  : in  std_logic;
         mmcm_locked_out      : out std_logic;
         sgmii_clk_r          : out std_logic;
         sgmii_clk_f          : out std_logic;
         sgmii_clk_en         : out std_logic;
         clk125_out           : out std_logic;
         clk625_out           : out std_logic;
         clk312_out           : out std_logic;
         rst_125_out          : out std_logic;
         refclk625_n          : in  std_logic;
         refclk625_p          : in  std_logic;
         gmii_txd             : in  std_logic_vector(7 downto 0);
         gmii_tx_en           : in  std_logic;
         gmii_tx_er           : in  std_logic;
         gmii_rxd             : out std_logic_vector(7 downto 0);
         gmii_rx_dv           : out std_logic;
         gmii_rx_er           : out std_logic;
         gmii_isolate         : out std_logic;
         configuration_vector : in  std_logic_vector(4 downto 0);
         speed_is_10_100      : in  std_logic;
         speed_is_100         : in  std_logic;
         status_vector        : out std_logic_vector(15 downto 0);
         reset                : in  std_logic;
         signal_detect        : in  std_logic;
         idelay_rdy_out       : out std_logic
         );
   end component;

begin

   U_GigEthLvdsUltraScaleCore : GigEthLvdsUltraScaleCore
      port map (
         -- Clocks and Resets
         refclk625_p           => sgmiiClkP,  -- [in]
         refclk625_n           => sgmiiClkN,  -- [in]
         clk125_out            => sysClk125,  -- [out]
         clk312_out            => open,  -- [out]
         clk625_out            => open,  -- [out]
         reset                 => coreRst,  -- [in]
         rst_125_out           => sysRst125,  -- [out]
         sgmii_clk_r           => open,  -- [out]
         sgmii_clk_f           => open,  -- [out]
         sgmii_clk_en          => sysClkEn,  -- [out]
         -- LVDS serial ports
         txp                   => sgmiiTxP,  -- [out]
         txn                   => sgmiiTxN,  -- [out]
         rxp                   => sgmiiRxP,  -- [in]
         rxn                   => sgmiiRxN,  -- [in]
         -- PHY Interface
         gmii_txd              => gmiiTxd,  -- [in]
         gmii_tx_en            => gmiiTxEn,  -- [in]
         gmii_tx_er            => gmiiTxEr,  -- [in]
         gmii_rxd              => gmiiRxd,  -- [out]
         gmii_rx_dv            => gmiiRxDv,  -- [out]
         gmii_rx_er            => gmiiRxEr,  -- [out]
         gmii_isolate          => open,  -- [out]
         -- Configuration and Status
         configuration_vector  => coreConfig,  -- [in]
         status_vector         => coreStatus,  -- [out]
         mmcm_locked_out       => open,  -- [out]
         speed_is_10_100       => speed_is_10_100,  -- [in]
         speed_is_100          => speed_is_100,  -- [in]
         idelay_rdy_out        => open,  -- [out]
         signal_detect         => sigDet);  -- [in]
end architecture rtl;
