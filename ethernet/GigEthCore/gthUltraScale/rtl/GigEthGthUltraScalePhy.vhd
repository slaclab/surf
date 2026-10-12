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
      -- False: fabric reference on sysClk125. True: dedicated reference on the
      -- gtRefClk port. One checkpoint serves both; this selects CPLLREFCLKSEL
      -- rather than choosing between separate checkpoints.
      USE_GTREFCLK_G   : boolean               := false;
      -- With USE_GTREFCLK_G, which dedicated channel input gtRefClk arrives
      -- on: 0 for GTREFCLK0, 1 for GTREFCLK1. The quad's MGTREFCLK0 and
      -- MGTREFCLK1 pin pairs feed these two inputs respectively and no route
      -- connects them, so this must match the pin the board reference lands
      -- on. Ignored when USE_GTREFCLK_G is false.
      GTREFCLK_INDEX_G : natural range 0 to 1 := 0);
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
         -- GT reference selection. The checkpoint no longer ties CPLLREFCLKSEL
         -- internally, so one core serves every reference path: high takes the
         -- fabric clock on gt0_gtgrefclk_in, low a dedicated reference.
         -- gt0_userefclk1_in then names the dedicated input, gtrefclk on
         -- GTREFCLK0 or gt0_gtrefclk1_in on GTREFCLK1. A .dcp carries no VHDL
         -- defaults, so all four are driven explicitly below.
         gt0_usegtgrefclk_in    : in  std_logic;
         gt0_gtgrefclk_in       : in  std_logic;
         gt0_userefclk1_in      : in  std_logic;
         gt0_gtrefclk1_in       : in  std_logic;
         status_vector          : out std_logic_vector(15 downto 0);  -- Core status.
         reset                  : in  std_logic;  -- Asynchronous reset for entire core.
         signal_detect          : in  std_logic);  -- Input from PMD to indicate presence of optical input.
   end component;

begin

   -- One checkpoint serves every reference path: it no longer ties
   -- CPLLREFCLKSEL internally, so the selection below is what routes the GT.
   -- Every mode requires related 125/62.5 MHz user clocks and a stretched reset.
   -- The dedicated clock drives only the channel input GTREFCLK_INDEX_G
   -- selects: routing one net to both MGTREFCLK inputs of a quad is not
   -- possible, so the unselected dedicated input is tied low instead. The
   -- fabric input is always connected, so the selected source is a real clock
   -- and no GT input is left floating.
   U_GigEthGthUltraScaleCore : GigEthGthUltraScaleCore
      port map (
         -- Clocks and Resets
         -- Dedicated reference on GTREFCLK0 when selected, else the fabric
         -- clock, so this input is driven by a real clock in every mode.
         gtrefclk               => ite(USE_GTREFCLK_G and GTREFCLK_INDEX_G = 0,
                                       gtRefClk, sysClk125),
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
         -- GT reference selection: the fabric 125 MHz clock, or the dedicated
         -- GT buffer output when USE_GTREFCLK_G is set. GTREFCLK_INDEX_G then
         -- picks the dedicated channel input, matching the MGTREFCLK pin pair
         -- the board reference physically arrives on.
         gt0_usegtgrefclk_in    => ite(USE_GTREFCLK_G, '0', '1'),
         gt0_gtgrefclk_in       => sysClk125,                     -- [in]
         gt0_userefclk1_in      => ite(GTREFCLK_INDEX_G = 1, '1', '0'),
         gt0_gtrefclk1_in       => ite(USE_GTREFCLK_G and GTREFCLK_INDEX_G = 1,
                                       gtRefClk, '0'),
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
