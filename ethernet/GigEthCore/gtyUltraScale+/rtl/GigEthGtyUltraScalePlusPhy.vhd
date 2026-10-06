-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 1000BASE-X UltraScale+ GTY PHY with an external GMII MAC.
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
use surf.GigEthPkg.all;

entity GigEthGtyUltraScalePlusPhy is
   port (
      -- Existing checkpoint clock contract: related 125/62.5 MHz fabric clocks.
      sysClk125  : in  sl;
      sysClk62   : in  sl;
      coreRst    : in  sl;
      coreConfig : in  slv(4 downto 0);
      coreStatus : out slv(15 downto 0);
      gmiiTxd    : in  slv(7 downto 0);
      gmiiTxEn   : in  sl;
      gmiiTxEr   : in  sl;
      gmiiRxd    : out slv(7 downto 0);
      gmiiRxDv   : out sl;
      gmiiRxEr   : out sl;

      -- Physical controls and serial interface.
      sigDet       : in  sl := '1';
      gtTxPolarity : in  sl := '0';
      gtRxPolarity : in  sl := '0';
      gtTxP        : out sl;
      gtTxN        : out sl;
      gtRxP        : in  sl;
      gtRxN        : in  sl);
end entity GigEthGtyUltraScalePlusPhy;

architecture rtl of GigEthGtyUltraScalePlusPhy is

   -- The implementation is a DCP, not an analyzed VHDL entity. Vivado binds
   -- this component to the checkpoint loaded by the family ruckus manifest.
   component GigEthGtyUltraScaleCore
      port (
         gtrefclk               : in  std_logic;
         txp                    : out std_logic;
         txn                    : out std_logic;
         rxp                    : in  std_logic;
         rxn                    : in  std_logic;
         resetdone              : out std_logic;
         cplllock               : out std_logic;
         mmcm_reset             : out std_logic;
         txoutclk               : out std_logic;
         rxoutclk               : out std_logic;
         userclk                : in  std_logic;
         userclk2               : in  std_logic;
         rxuserclk              : in  std_logic;
         rxuserclk2             : in  std_logic;
         pma_reset              : in  std_logic;
         mmcm_locked            : in  std_logic;
         independent_clock_bufg : in  std_logic;
         gmii_txd               : in  std_logic_vector(7 downto 0);
         gmii_tx_en             : in  std_logic;
         gmii_tx_er             : in  std_logic;
         gmii_rxd               : out std_logic_vector(7 downto 0);
         gmii_rx_dv             : out std_logic;
         gmii_rx_er             : out std_logic;
         gmii_isolate           : out std_logic;
         configuration_vector   : in  std_logic_vector(4 downto 0);
         an_interrupt           : out std_logic;
         an_adv_config_vector   : in  std_logic_vector(15 downto 0);
         an_restart_config      : in  std_logic;
         status_vector          : out std_logic_vector(15 downto 0);
         reset                  : in  std_logic;
         gtpowergood            : out std_logic;
         signal_detect          : in  std_logic;
         gt0_txpolarity_in      : in  std_logic;
         gt0_rxpolarity_in      : in  std_logic
         );
   end component;

begin

   -- Preserve the existing checkpoint wiring. sysClk125 also feeds gtrefclk;
   -- this is not a new dedicated-MGT-reference interface. Reference routing,
   -- clock continuity and connector latency need device/board qualification.
   -- coreRst must be asserted/stretched and released by the enclosing design.
   U_GigEthGtyUltraScaleCore : GigEthGtyUltraScaleCore
      port map (
         -- Clocks and Resets
         gtrefclk               => sysClk125,                     -- [in]
         independent_clock_bufg => sysClk62,                      -- [in]
         txoutclk               => open,                          -- [out]
         rxoutclk               => open,                          -- [out]
         userclk                => sysClk62,                      -- [in]
         userclk2               => sysClk125,                     -- [in]
         rxuserclk              => sysClk62,                      -- [in]
         rxuserclk2             => sysClk62,                      -- [in]
         reset                  => coreRst,                       -- [in]
         pma_reset              => coreRst,                       -- [in]
         resetdone              => open,                          -- [out]
         mmcm_locked            => '1',                           -- [in]
         mmcm_reset             => open,                          -- [out]
         gtpowergood            => open,                          -- [out]
         cplllock               => open,                          -- [out]
         -- PHY Interface
         gmii_txd               => gmiiTxd,                       -- [in]
         gmii_tx_en             => gmiiTxEn,                      -- [in]
         gmii_tx_er             => gmiiTxEr,                      -- [in]
         gmii_rxd               => gmiiRxd,                       -- [out]
         gmii_rx_dv             => gmiiRxDv,                      -- [out]
         gmii_rx_er             => gmiiRxEr,                      -- [out]
         gmii_isolate           => open,                          -- [out]
         -- MGT Ports
         txp                    => gtTxP,                         -- [out]
         txn                    => gtTxN,                         -- [out]
         rxp                    => gtRxP,                         -- [in]
         rxn                    => gtRxN,                         -- [in]
         -- Configuration and Status
         an_restart_config      => '0',                           -- [in]
         an_adv_config_vector   => GIG_ETH_AN_ADV_CONFIG_INIT_C,  -- [in]
         an_interrupt           => open,                          -- [out]
         configuration_vector   => coreConfig,                    -- [in]
         status_vector          => coreStatus,                    -- [out]
         gt0_txpolarity_in      => gtTxPolarity,                  -- [in]
         gt0_rxpolarity_in      => gtRxPolarity,                  -- [in]
         signal_detect          => sigDet);                       -- [in]

end architecture rtl;
