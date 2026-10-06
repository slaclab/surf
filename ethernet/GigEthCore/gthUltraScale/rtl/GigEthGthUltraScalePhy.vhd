-------------------------------------------------------------------------------
-- Company    : SLAC National Accelerator Laboratory
-------------------------------------------------------------------------------
-- Description: 1000BASE-X UltraScale GTH PHY with an external GMII MAC.
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

entity GigEthGthUltraScalePhy is
   generic (
      -- False: legacy fabric reference. True: dedicated GTREFCLK1 checkpoint.
      USE_GTREFCLK_G : boolean := false);
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
      gtRxN        : in  sl;
      -- Used only with USE_GTREFCLK_G; supply the dedicated GT-buffer output.
      gtRefClk     : in  sl := '0');
end entity GigEthGthUltraScalePhy;

architecture rtl of GigEthGthUltraScalePhy is

   -- The implementation is a DCP, not an analyzed VHDL entity. Vivado binds
   -- this component to the checkpoint loaded by the family ruckus manifest.
   component GigEthGthUltraScaleCore
      port (
         ---------------------
         -- Transceiver Interface
         ---------------------
         gtrefclk               : in  std_logic;  -- Very high quality clock for GT transceiver.
         txp                    : out std_logic;  -- Differential +ve of serial transmission from PMA to PMD.
         txn                    : out std_logic;  -- Differential -ve of serial transmission from PMA to PMD.
         rxp                    : in  std_logic;  -- Differential +ve for serial reception from PMD to PMA.
         rxn                    : in  std_logic;  -- Differential -ve for serial reception from PMD to PMA.
         resetdone              : out std_logic;  -- The GT transceiver has completed its reset cycle
         cplllock               : out std_logic;  -- The GT transceiver has completed its reset cycle
         mmcm_reset             : out std_logic;
         txoutclk               : out std_logic;
         rxoutclk               : out std_logic;
         userclk                : in  std_logic;
         userclk2               : in  std_logic;
         rxuserclk              : in  std_logic;
         rxuserclk2             : in  std_logic;
         pma_reset              : in  std_logic;  -- transceiver PMA reset signal
         mmcm_locked            : in  std_logic;  -- MMCM Locked
         independent_clock_bufg : in  std_logic;
         -----------------
         -- GMII Interface
         -----------------
         gmii_txd               : in  std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
         gmii_tx_en             : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_tx_er             : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_rxd               : out std_logic_vector(7 downto 0);  -- Received Data to client MAC.
         gmii_rx_dv             : out std_logic;  -- Received control signal to client MAC.
         gmii_rx_er             : out std_logic;  -- Received control signal to client MAC.
         gmii_isolate           : out std_logic;  -- Tristate control to electrically isolate GMII.
         --------------------------------------------
         -- Management: Alternative to MDIO Interface
         --------------------------------------------
         configuration_vector   : in  std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
         an_interrupt           : out std_logic;  -- Interrupt to processor to signal that Auto-Negotiation has completed
         an_adv_config_vector   : in  std_logic_vector(15 downto 0);  -- Alternate interface to program REG4 (AN ADV)
         an_restart_config      : in  std_logic;  -- Alternate signal to modify AN restart bit in REG0
         ---------------
         -- General IO's
         ---------------
         gt0_txpolarity_in      : in  std_logic;
         gt0_rxpolarity_in      : in  std_logic;
         status_vector          : out std_logic_vector(15 downto 0);  -- Core status.
         reset                  : in  std_logic;  -- Asynchronous reset for entire core.
         signal_detect          : in  std_logic);  -- Input from PMD to indicate presence of optical input.
   end component;

   -- Separate DCP module names are required: reference routing is fixed inside
   -- each synthesized checkpoint, not selected by a fabric clock mux.
   component GigEthGthUltraScaleRefCore
      port (
         ---------------------
         -- Transceiver Interface
         ---------------------
         gtrefclk               : in  std_logic;  -- Very high quality clock for GT transceiver.
         txp                    : out std_logic;  -- Differential +ve of serial transmission from PMA to PMD.
         txn                    : out std_logic;  -- Differential -ve of serial transmission from PMA to PMD.
         rxp                    : in  std_logic;  -- Differential +ve for serial reception from PMD to PMA.
         rxn                    : in  std_logic;  -- Differential -ve for serial reception from PMD to PMA.
         resetdone              : out std_logic;  -- The GT transceiver has completed its reset cycle
         cplllock               : out std_logic;  -- The GT transceiver has completed its reset cycle
         mmcm_reset             : out std_logic;
         txoutclk               : out std_logic;
         rxoutclk               : out std_logic;
         userclk                : in  std_logic;
         userclk2               : in  std_logic;
         rxuserclk              : in  std_logic;
         rxuserclk2             : in  std_logic;
         pma_reset              : in  std_logic;  -- transceiver PMA reset signal
         mmcm_locked            : in  std_logic;  -- MMCM Locked
         independent_clock_bufg : in  std_logic;
         -----------------
         -- GMII Interface
         -----------------
         gmii_txd               : in  std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
         gmii_tx_en             : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_tx_er             : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_rxd               : out std_logic_vector(7 downto 0);  -- Received Data to client MAC.
         gmii_rx_dv             : out std_logic;  -- Received control signal to client MAC.
         gmii_rx_er             : out std_logic;  -- Received control signal to client MAC.
         gmii_isolate           : out std_logic;  -- Tristate control to electrically isolate GMII.
         --------------------------------------------
         -- Management: Alternative to MDIO Interface
         --------------------------------------------
         configuration_vector   : in  std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
         an_interrupt           : out std_logic;  -- Interrupt to processor to signal that Auto-Negotiation has completed
         an_adv_config_vector   : in  std_logic_vector(15 downto 0);  -- Alternate interface to program REG4 (AN ADV)
         an_restart_config      : in  std_logic;  -- Alternate signal to modify AN restart bit in REG0
         ---------------
         -- General IO's
         ---------------
         gt0_txpolarity_in      : in  std_logic;
         gt0_rxpolarity_in      : in  std_logic;
         status_vector          : out std_logic_vector(15 downto 0);  -- Core status.
         reset                  : in  std_logic;  -- Asynchronous reset for entire core.
         signal_detect          : in  std_logic);  -- Input from PMD to indicate presence of optical input.
   end component;

begin

   -- Both modes require related 125/62.5 MHz user clocks and a stretched reset.
   -- Keep the legacy checkpoint wiring and default behavior unchanged.
   GEN_FABRIC_REF : if (USE_GTREFCLK_G = false) generate
      U_GigEthGthUltraScaleCore : GigEthGthUltraScaleCore
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
   end generate GEN_FABRIC_REF;

   -- This checkpoint routes gtrefclk to GTREFCLK1 with CPLLREFCLKSEL=010.
   -- Its creation, binding and dedicated routing still need Vivado qualification.
   GEN_GT_REF : if (USE_GTREFCLK_G = true) generate
      U_GigEthGthUltraScaleRefCore : GigEthGthUltraScaleRefCore
         port map (
            -- Clocks and Resets
            gtrefclk               => gtRefClk,                     -- [in]
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
   end generate GEN_GT_REF;

end architecture rtl;
