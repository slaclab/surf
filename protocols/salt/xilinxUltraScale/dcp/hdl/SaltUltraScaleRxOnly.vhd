--------------------------------------------------------------------------------
-- File       : SaltUltraScaleCore.vhd
-- Author     : Xilinx Inc.
--------------------------------------------------------------------------------
-- (c) Copyright 2009 Xilinx, Inc. All rights reserved.
--
-- This file contains confidential and proprietary information
-- of Xilinx, Inc. and is protected under U.S. and
-- international copyright and other intellectual property
-- laws.
--
-- DISCLAIMER
-- This disclaimer is not a license and does not grant any
-- rights to the materials distributed herewith. Except as
-- otherwise provided in a valid license issued to you by
-- Xilinx, and to the maximum extent permitted by applicable
-- law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
-- WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
-- AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
-- BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
-- INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
-- (2) Xilinx shall not be liable (whether in contract or tort,
-- including negligence, or under any other theory of
-- liability) for any loss or damage of any kind or nature
-- related to, arising under or in connection with these
-- materials, including for any direct, or any indirect,
-- special, incidental, or consequential loss or damage
-- (including loss of data, profits, goodwill, or any type of
-- loss or damage suffered as a result of any action brought
-- by a third party) even if such damage or loss was
-- reasonably foreseeable or Xilinx had been advised of the
-- possibility of the same.
--
-- CRITICAL APPLICATIONS
-- Xilinx products are not designed or intended to be fail-
-- safe, or for use in any application requiring fail-safe
-- performance, such as life-support or safety devices or
-- systems, Class III medical devices, nuclear facilities,
-- applications related to the deployment of airbags, or any
-- other applications that could lead to death, personal
-- injury, or severe property or environmental damage
-- (individually and collectively, "Critical
-- Applications"). Customer assumes the sole risk and
-- liability of any use of Xilinx products in Critical
-- Applications, subject only to applicable laws and
-- regulations governing limitations on product liability.
--
-- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
-- PART OF THIS FILE AT ALL TIMES. 
 
--------------------------------------------------------------------------------
-- Description: This Core Block Level wrapper connects the core to a LVDS 
--              transceiver implementation
--
--              The SGMII adaptation module is provided to convert
--              between 1Gbps and 10/100 Mbps rates.  This is connected
--              to the MAC side of the core to provide a GMII style
--              interface.  When the core is running at 1Gbps speeds,
--              the GMII (8-bitdata pathway) is used at a clock
--              frequency of 125MHz.  When the core is running at
--              100Mbps, a clock frequency of 12.5MHz is used.  When
--              running at 100Mbps speeds, a clock frequency of 1.25MHz
--              is used.
--
--    ----------------------------------------------------------------
--    |                   Core Block Level Wrapper                   |
--    |                                                              |
--    |                                                              |
--    |                  --------------          --------------      |
--    |                  |    Core    |          |    LVDS    |      |
--    |                  |            |          | transceiver|      |
--    |    ---------     |            |          |            |      |
--    |    |       |     |            |          |            |      |
--    |    | SGMII |     |            |          |            |      |
--  ------>| Adapt |---->| GMII       |--------->|        TXP |-------->
--    |    | Module|     | Tx         |          |        TXN |      |
--    |    |       |     |            |          |            |      |
--    |    |       |     |            |  trans-  |            |      |
--    |    |       |     |            | ceiver   |            |      |
--    |    |       |     |            |    I/F   |            |      |
--    |    |       |     |            |          |            |      |
--    |    |       |     | GMII       |          |        RXP |      |
--  <------|       |<----| Rx         |<---------|        RXN |<--------
--    |    |       |     |            |          |            |      |
--    |    ---------     --------------          --------------      |
--    |                                                              |
--    ----------------------------------------------------------------


library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
USE IEEE.std_logic_unsigned.ALL;
USE IEEE.std_logic_arith.ALL;
use ieee.numeric_std.all; 
library gig_ethernet_pcs_pma_v15_1_0;
use gig_ethernet_pcs_pma_v15_1_0.all;
--------------------------------------------------------------------------------
-- The entity declaration for the Core Block wrapper.
--------------------------------------------------------------------------------


entity SaltUltraScaleRxOnly is

      port (
      -- LVDS transceiver Interface
      -----------------------------


      -- txp      : out std_logic;                   -- Differential +ve of serial transmission from PMA to PMD.
      -- txn      : out std_logic;                   -- Differential -ve of serial transmission from PMA to PMD.
      rxp      : in std_logic;                    -- Differential +ve for serial reception from PMD to PMA.
      rxn      : in std_logic;                    -- Differential -ve for serial reception from PMD to PMA.


      clk125m     : in std_logic;
      clk625 : in std_logic;
      idelay_rdy_in : in std_logic;
      clk312      : in std_logic;
      mmcm_locked  : in std_logic;
      sgmii_clk_r   : out std_logic;                -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
      sgmii_clk_f   : out std_logic;                -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
      sgmii_clk_en: out std_logic;                -- Clock enable for client MAC
      -- Speed Control
      speed_is_10_100      : in std_logic;                     -- Core should operate at either 10Mbps or 100Mbps speeds
      speed_is_100         : in std_logic;                     -- Core should operate at 100Mbps speed
      -- GMII Interface
      -----------------
      gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
      gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
      gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.


      configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
      -- General IO's
      ---------------
      status_vector        : out std_logic_vector(15 downto 0); -- Core status.
      reset                : in std_logic;                     -- Asynchronous reset for entire core.
      signal_detect        : in std_logic                      -- Input from PMD to indicate presence of optical input.

);
end SaltUltraScaleRxOnly;

architecture block_level of SaltUltraScaleRxOnly is

   attribute DowngradeIPIdentifiedWarnings: string;
   attribute DowngradeIPIdentifiedWarnings of block_level : architecture is "yes";

   -----------------------------------------------------------------------------
   -- Component Declaration for the LVDS transceiver module
   -----------------------------------------------------------------------------
   component SaltUltraScaleCore_block
   
   port (
      -- LVDS transceiver Interface
      -----------------------------


      -- txp      : out std_logic;                   -- Differential +ve of serial transmission from PMA to PMD.
      -- txn      : out std_logic;                   -- Differential -ve of serial transmission from PMA to PMD.
      rxp      : in std_logic;                    -- Differential +ve for serial reception from PMD to PMA.
      rxn      : in std_logic;                    -- Differential -ve for serial reception from PMD to PMA.

      clk125m     : in std_logic;
      clk625      : in std_logic;
      idelay_rdy_in : in std_logic;
      clk312      : in std_logic;
      mmcm_locked  : in std_logic;
      sgmii_clk_r   : out std_logic;                -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
      sgmii_clk_f   : out std_logic;                -- Clock for client MAC (125Mhz, 12.5MHz or 1.25MHz).
      sgmii_clk_en: out std_logic;                -- Clock enable for client MAC
      -- Speed Control
      speed_is_10_100      : in std_logic;                     -- Core should operate at either 10Mbps or 100Mbps speeds
      speed_is_100         : in std_logic;                     -- Core should operate at 100Mbps speed
      -- GMII Interface
      -----------------
      gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
      gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
      gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.


      configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.
      -- General IO's
      ---------------
      status_vector        : out std_logic_vector(15 downto 0); -- Core status.
      reset                : in std_logic;                     -- Asynchronous reset for entire core.
      signal_detect        : in std_logic                      -- Input from PMD to indicate presence of optical input.

);
end component;


ATTRIBUTE CORE_GENERATION_INFO : STRING;
ATTRIBUTE CORE_GENERATION_INFO OF block_level : ARCHITECTURE IS "SaltUltraScaleCore,gig_ethernet_pcs_pma_v15_1_0,{x_ipProduct=Vivado 2015.3,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=gig_ethernet_pcs_pma,x_ipVersion=15.1,x_ipCoreRevision=0,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,c_elaboration_transient_dir=.,c_component_name=SaltUltraScaleCore,c_family=kintexu,c_is_sgmii=true,c_use_transceiver=false,c_use_tbi=false,c_is_2_5g=false,c_use_lvds=true,c_has_an=false,c_has_mdio=false,c_has_ext_mdio=false,c_sgmii_phy_mode=false,c_dynamic_switching=false,c_sgmii_fabric_buffer=true,c_1588=0,gt_rx_byte_width=1,C_EMAC_IF_TEMAC=true,C_PHYADDR=1,EXAMPLE_SIMULATION=0,c_support_level=false,c_sub_core_name=SaltUltraScaleCore_gt,c_transceiver_type=GTHE3,c_transceivercontrol=false,c_xdevicefamily=xcku040,c_gt_dmonitorout_width=17,c_gt_drpaddr_width=9,c_gt_txdiffctrl_width=4,c_gt_rxmonitorout_width=7,c_num_of_lanes=1,c_refclkrate=125,c_drpclkrate=50.0}";
ATTRIBUTE X_CORE_INFO : STRING;
ATTRIBUTE X_CORE_INFO OF block_level: ARCHITECTURE IS "gig_ethernet_pcs_pma_v15_1_0,Vivado 2015.3";

begin

   U0 : SaltUltraScaleCore_block
   port map(
      -- LVDS transceiver Interface
      -----------------------------


      -- txp                   => txp,
      -- txn                   => txn,
      rxp                   => rxp,
      rxn                   => rxn,
      clk125m               => clk125m,
      clk625                => clk625,
      idelay_rdy_in         => idelay_rdy_in,
      clk312                => clk312, 
      mmcm_locked           => mmcm_locked,

      sgmii_clk_r             => sgmii_clk_r,
      sgmii_clk_f             => sgmii_clk_f,
      sgmii_clk_en          => sgmii_clk_en,
      ----------------
      -- Speed Control
      ----------------
      speed_is_10_100       => speed_is_10_100,
      speed_is_100          => speed_is_100,
      -- GMII Interface
      -----------------
      gmii_txd              => gmii_txd,
      gmii_tx_en            => gmii_tx_en,
      gmii_tx_er            => gmii_tx_er,
      gmii_rxd              => gmii_rxd,
      gmii_rx_dv            => gmii_rx_dv,
      gmii_rx_er            => gmii_rx_er,
      gmii_isolate          => gmii_isolate,



      configuration_vector  => configuration_vector,
      -- General IO's
      ---------------
      status_vector         => status_vector,
      reset                 => reset,
      signal_detect         => signal_detect
);

end block_level;
