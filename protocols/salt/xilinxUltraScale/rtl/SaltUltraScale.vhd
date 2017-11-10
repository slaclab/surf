-------------------------------------------------------------------------------
-- File       : SaltUltraScale.vhd
-- Company    : SLAC National Accelerator Laboratory
-- Created    : 2015-06-15
-- Last update: 2017-11-08
-------------------------------------------------------------------------------
-- Description: SLAC Asynchronous Logic Transceiver (SALT) UltraScale Core
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
use work.AxiStreamPkg.all;
use work.SsiPkg.all;

library unisim;
use unisim.vcomponents.all;

entity SaltUltraScale is
   generic (
      TPD_G               : time                := 1 ns;
      SIMULATION_G        : boolean             := false;
      TX_ENABLE_G         : boolean             := true;
      RX_ENABLE_G         : boolean             := true;
      COMMON_TX_CLK_G     : boolean             := false;  -- Set to true if sAxisClk and clk are the same clock
      COMMON_RX_CLK_G     : boolean             := false;  -- Set to true if mAxisClk and clk are the same clock      
      SLAVE_AXI_CONFIG_G  : AxiStreamConfigType := ssiAxiStreamConfig(4);
      MASTER_AXI_CONFIG_G : AxiStreamConfigType := ssiAxiStreamConfig(4));
   port (
      -- TX Serial Stream
      txP           : out sl;
      txN           : out sl;
      -- RX Serial Stream
      rxP           : in  sl;
      rxN           : in  sl;
      -- Reference Signals
      clk125MHz     : in  sl;
      rst125MHz     : in  sl;
      clk312MHz     : in  sl;
      clk625MHz     : in  sl;
      iDelayCtrlRdy : in  sl;
      mmcmLocked    : in  sl := '1';
      loopback      : in  sl := '0';
      powerDown     : in  sl := '0';
      linkUp        : out sl;
      txPktSent     : out sl;
      rxPktRcvd     : out sl;
      -- Slave Port
      sAxisClk      : in  sl;
      sAxisRst      : in  sl;
      sAxisMaster   : in  AxiStreamMasterType;
      sAxisSlave    : out AxiStreamSlaveType;
      -- Master Port
      mAxisClk      : in  sl;
      mAxisRst      : in  sl;
      mAxisMaster   : out AxiStreamMasterType;
      mAxisSlave    : in  AxiStreamSlaveType);
end SaltUltraScale;

architecture mapping of SaltUltraScale is

   component SaltUltraScaleCore
      port (
         -----------------------------
         -- LVDS transceiver Interface
         -----------------------------
         txp                  : out std_logic;  -- Differential +ve of serial transmission from PMA to PMD.
         txn                  : out std_logic;  -- Differential -ve of serial transmission from PMA to PMD.
         rxp                  : in  std_logic;  -- Differential +ve for serial reception from PMD to PMA.
         rxn                  : in  std_logic;  -- Differential -ve for serial reception from PMD to PMA.
         clk125m              : in  std_logic;
         mmcm_locked          : in  std_logic;
         sgmii_clk_r          : out std_logic;  -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
         sgmii_clk_f          : out std_logic;  -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
         sgmii_clk_en         : out std_logic;  -- Clock enable for client MAC
         ----------------
         -- Speed Control
         ----------------
         speed_is_10_100      : in  std_logic;  -- Core should operate at either 10Mbps or 100Mbps speeds
         speed_is_100         : in  std_logic;  -- Core should operate at 100Mbps speed
         clk625               : in  std_logic;
         clk312               : in  std_logic;
         idelay_rdy_in        : in  std_logic;
         -----------------
         -- GMII Interface
         -----------------
         gmii_txd             : in  std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
         gmii_tx_en           : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_tx_er           : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_rxd             : out std_logic_vector(7 downto 0);  -- Received Data to client MAC.
         gmii_rx_dv           : out std_logic;  -- Received control signal to client MAC.
         gmii_rx_er           : out std_logic;  -- Received control signal to client MAC.
         gmii_isolate         : out std_logic;  -- Tristate control to electrically isolate GMII.
         ---------------
         -- General IO's
         ---------------
         configuration_vector : in  std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
         status_vector        : out std_logic_vector(15 downto 0);  -- Core status.
         reset                : in  std_logic;  -- Asynchronous reset for entire core.
         signal_detect        : in  std_logic);  -- Input from PMD to indicate presence of optical input.
   end component;

   component SaltUltraScaleRxOnly
      port (
         -----------------------------
         -- LVDS transceiver Interface
         -----------------------------
         rxp                  : in  std_logic;  -- Differential +ve for serial reception from PMD to PMA.
         rxn                  : in  std_logic;  -- Differential -ve for serial reception from PMD to PMA.
         clk125m              : in  std_logic;
         mmcm_locked          : in  std_logic;
         sgmii_clk_r          : out std_logic;  -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
         sgmii_clk_f          : out std_logic;  -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
         sgmii_clk_en         : out std_logic;  -- Clock enable for client MAC
         ----------------
         -- Speed Control
         ----------------
         speed_is_10_100      : in  std_logic;  -- Core should operate at either 10Mbps or 100Mbps speeds
         speed_is_100         : in  std_logic;  -- Core should operate at 100Mbps speed
         clk625               : in  std_logic;
         clk312               : in  std_logic;
         idelay_rdy_in        : in  std_logic;
         -----------------
         -- GMII Interface
         -----------------
         gmii_txd             : in  std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
         gmii_tx_en           : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_tx_er           : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_rxd             : out std_logic_vector(7 downto 0);  -- Received Data to client MAC.
         gmii_rx_dv           : out std_logic;  -- Received control signal to client MAC.
         gmii_rx_er           : out std_logic;  -- Received control signal to client MAC.
         gmii_isolate         : out std_logic;  -- Tristate control to electrically isolate GMII.
         ---------------
         -- General IO's
         ---------------
         configuration_vector : in  std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
         status_vector        : out std_logic_vector(15 downto 0);  -- Core status.
         reset                : in  std_logic;  -- Asynchronous reset for entire core.
         signal_detect        : in  std_logic);  -- Input from PMD to indicate presence of optical input.
   end component;

   component SaltUltraScaleTxOnly
      port (
         -----------------------------
         -- LVDS transceiver Interface
         -----------------------------
         txp                  : out std_logic;  -- Differential +ve of serial transmission from PMA to PMD.
         txn                  : out std_logic;  -- Differential -ve of serial transmission from PMA to PMD.
         clk125m              : in  std_logic;
         mmcm_locked          : in  std_logic;
         sgmii_clk_r          : out std_logic;  -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
         sgmii_clk_f          : out std_logic;  -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
         sgmii_clk_en         : out std_logic;  -- Clock enable for client MAC
         ----------------
         -- Speed Control
         ----------------
         speed_is_10_100      : in  std_logic;  -- Core should operate at either 10Mbps or 100Mbps speeds
         speed_is_100         : in  std_logic;  -- Core should operate at 100Mbps speed
         clk625               : in  std_logic;
         clk312               : in  std_logic;
         -----------------
         -- GMII Interface
         -----------------
         gmii_txd             : in  std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
         gmii_tx_en           : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_tx_er           : in  std_logic;  -- Transmit control signal from client MAC.
         gmii_rxd             : out std_logic_vector(7 downto 0);  -- Received Data to client MAC.
         gmii_rx_dv           : out std_logic;  -- Received control signal to client MAC.
         gmii_rx_er           : out std_logic;  -- Received control signal to client MAC.
         gmii_isolate         : out std_logic;  -- Tristate control to electrically isolate GMII.
         ---------------
         -- General IO's
         ---------------
         configuration_vector : in  std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
         status_vector        : out std_logic_vector(15 downto 0);  -- Core status.
         reset                : in  std_logic;  -- Asynchronous reset for entire core.
         signal_detect        : in  std_logic);  -- Input from PMD to indicate presence of optical input.
   end component;


   signal config : slv(4 downto 0);
   signal status : slv(15 downto 0) := (others => '0');

   signal txEn   : sl;
   signal txData : slv(7 downto 0);

   signal rxEn   : sl;
   signal rxErr  : sl;
   signal rxData : slv(7 downto 0);

begin

   linkUp <= status(0);

   config(0) <= '1';                    -- Unidirectional Enabled
   config(1) <= loopback;               -- loopback
   config(2) <= powerDown;              -- powerDown
   config(3) <= '0';                    -- Isolate Disabled
   config(4) <= '0';                    -- Auto-Negotiation Disabled

   FULL_DUPLEX : if ((TX_ENABLE_G = true) and (RX_ENABLE_G = true)) or (SIMULATION_G = true) generate
      U_SaltUltraScaleCore : SaltUltraScaleCore
         port map(
            -----------------------------
            -- LVDS transceiver Interface
            -----------------------------
            txp                  => txP,
            txn                  => txN,
            rxp                  => rxP,
            rxn                  => rxN,
            clk125m              => clk125MHz,
            mmcm_locked          => mmcmLocked,
            sgmii_clk_r          => open,
            sgmii_clk_f          => open,
            sgmii_clk_en         => open,
            ----------------
            -- Speed Control
            ----------------
            speed_is_10_100      => '0',
            speed_is_100         => '0',
            clk625               => clk625MHz,
            clk312               => clk312MHz,
            idelay_rdy_in        => iDelayCtrlRdy,
            -----------------
            -- GMII Interface
            -----------------
            gmii_txd             => txData,
            gmii_tx_en           => txEn,
            gmii_tx_er           => '0',
            gmii_rxd             => rxData,
            gmii_rx_dv           => rxEn,
            gmii_rx_er           => rxErr,
            gmii_isolate         => open,
            ---------------
            -- General IO's
            ---------------
            configuration_vector => config,
            status_vector        => status,
            reset                => rst125MHz,
            signal_detect        => '1');
   end generate;

   RX_ONLY : if (TX_ENABLE_G = false) and (RX_ENABLE_G = true) and (SIMULATION_G = false) generate
      txp <= '0';
      txn <= '1';
      U_SaltUltraScaleCore : SaltUltraScaleRxOnly
         port map(
            -----------------------------
            -- LVDS transceiver Interface
            -----------------------------
            rxp                  => rxP,
            rxn                  => rxN,
            clk125m              => clk125MHz,
            mmcm_locked          => mmcmLocked,
            sgmii_clk_r          => open,
            sgmii_clk_f          => open,
            sgmii_clk_en         => open,
            ----------------
            -- Speed Control
            ----------------
            speed_is_10_100      => '0',
            speed_is_100         => '0',
            clk625               => clk625MHz,
            clk312               => clk312MHz,
            idelay_rdy_in        => iDelayCtrlRdy,
            -----------------
            -- GMII Interface
            -----------------
            gmii_txd             => x"00",
            gmii_tx_en           => '0',
            gmii_tx_er           => '0',
            gmii_rxd             => rxData,
            gmii_rx_dv           => rxEn,
            gmii_rx_er           => rxErr,
            gmii_isolate         => open,
            ---------------
            -- General IO's
            ---------------
            configuration_vector => config,
            status_vector        => status,
            reset                => rst125MHz,
            signal_detect        => '1');
   end generate;

   TX_ONLY : if (TX_ENABLE_G = true) and (RX_ENABLE_G = false) and (SIMULATION_G = false) generate
      U_SaltUltraScaleCore : SaltUltraScaleTxOnly
         port map(
            -----------------------------
            -- LVDS transceiver Interface
            -----------------------------
            txp                  => txP,
            txn                  => txN,
            clk125m              => clk125MHz,
            mmcm_locked          => mmcmLocked,
            sgmii_clk_r          => open,
            sgmii_clk_f          => open,
            sgmii_clk_en         => open,
            ----------------
            -- Speed Control
            ----------------
            speed_is_10_100      => '0',
            speed_is_100         => '0',
            clk625               => clk625MHz,
            clk312               => clk312MHz,
            -----------------
            -- GMII Interface
            -----------------
            gmii_txd             => txData,
            gmii_tx_en           => txEn,
            gmii_tx_er           => '0',
            gmii_rxd             => open,
            gmii_rx_dv           => open,
            gmii_rx_er           => open,
            gmii_isolate         => open,
            ---------------
            -- General IO's
            ---------------
            configuration_vector => config,
            status_vector        => open,
            reset                => rst125MHz,
            signal_detect        => '1');

      status(0) <= not(rst125MHz);
   end generate;

   TX_ENABLE : if (TX_ENABLE_G = true) generate
      SaltTx_Inst : entity work.SaltTx
         generic map(
            TPD_G              => TPD_G,
            SLAVE_AXI_CONFIG_G => SLAVE_AXI_CONFIG_G,
            COMMON_TX_CLK_G    => COMMON_TX_CLK_G)
         port map(
            -- Slave Port
            sAxisClk    => sAxisClk,
            sAxisRst    => sAxisRst,
            sAxisMaster => sAxisMaster,
            sAxisSlave  => sAxisSlave,
            -- GMII Interface
            txPktSent   => txPktSent,
            txEn        => txEn,
            txData      => txData,
            clk         => clk125MHz,
            rst         => rst125MHz);
   end generate;

   TX_DISABLE : if (TX_ENABLE_G = false) generate

      txData     <= x"BC";
      txPktSent  <= '0';
      txEn       <= '0';
      sAxisSlave <= AXI_STREAM_SLAVE_FORCE_C;

   end generate;

   RX_ENABLE : if (RX_ENABLE_G = true) generate
      SaltRx_Inst : entity work.SaltRx
         generic map(
            TPD_G               => TPD_G,
            MASTER_AXI_CONFIG_G => MASTER_AXI_CONFIG_G,
            COMMON_RX_CLK_G     => COMMON_RX_CLK_G)
         port map(
            -- Master Port
            mAxisClk    => mAxisClk,
            mAxisRst    => mAxisRst,
            mAxisMaster => mAxisMaster,
            mAxisSlave  => mAxisSlave,
            -- GMII Interface
            rxPktRcvd   => rxPktRcvd,
            rxEn        => rxEn,
            rxErr       => rxErr,
            rxData      => rxData,
            clk         => clk125MHz,
            rst         => rst125MHz);

   end generate;

   RX_DISABLE : if (RX_ENABLE_G = false) generate

      rxPktRcvd   <= '0';
      mAxisMaster <= AXI_STREAM_MASTER_INIT_C;

   end generate;

end mapping;
