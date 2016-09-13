--------------------------------------------------------------------------------
-- File       : GigEthGtx7Core.vhd
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
-- 
-- 
--------------------------------------------------------------------------------
-- Description: This Core Block Level wrapper connects the core to a  
--              Series-7 Transceiver.
--
--
--   ------------------------------------------------------------
--   |                      Core Block wrapper                  |
--   |                                                          |
--   |        ------------------          -----------------     |
--   |        |      Core      |          | Transceiver   |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
-- ---------->| GMII           |--------->|           TXP |-------->
--   |        | Tx             |          |           TXN |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        |                |          |               |     |
--   |        | GMII           |          |           RXP |     |
-- <----------| Rx             |<---------|           RXN |<--------
--   |        |                |          |               |     |
--   |        ------------------          -----------------     |
--   |                                                          |
--   ------------------------------------------------------------
--
--


library unisim;
use unisim.vcomponents.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all; 
library gig_ethernet_pcs_pma_v15_1_0;
use gig_ethernet_pcs_pma_v15_1_0.all;



--------------------------------------------------------------------------------
-- The entity declaration for the Core Block wrapper.
--------------------------------------------------------------------------------

entity GigEthGtx7Core is
      port(
      -- Transceiver Interface
      ---------------------


      gtrefclk                 : in  std_logic;                           -- Very high quality clock for GT transceiver.
      gtrefclk_bufg            : in  std_logic;
      
      txp                  : out std_logic;                    -- Differential +ve of serial transmission from PMA to PMD.
      txn                  : out std_logic;                    -- Differential -ve of serial transmission from PMA to PMD.
      rxp                  : in std_logic;                     -- Differential +ve for serial reception from PMD to PMA.
      rxn                  : in std_logic;                     -- Differential -ve for serial reception from PMD to PMA.
      resetdone                : out std_logic;                           -- The GT transceiver has completed its reset cycle
      cplllock                : out std_logic;                           -- The GT transceiver has completed its reset cycle
      mmcm_reset              : out std_logic;         
      txoutclk                 : out std_logic;                     
      rxoutclk                 : out std_logic;                     
      userclk                  : in  std_logic;                     
      userclk2                 : in  std_logic;                     
      rxuserclk                  : in  std_logic;                   
      rxuserclk2                 : in  std_logic;                   
      pma_reset                : in  std_logic;                           -- transceiver PMA reset signal
      mmcm_locked              : in  std_logic;                           -- MMCM Locked
      independent_clock_bufg : in std_logic;                   

      -- GMII Interface
      -----------------
      gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
      gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
      gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.

      -- Management: Alternative to MDIO Interface
      --------------------------------------------

      configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.



      -- General IO's
      ---------------
      status_vector        : out std_logic_vector(15 downto 0); -- Core status.
      reset                : in std_logic;                     -- Asynchronous reset for entire core.
     
      signal_detect         : in std_logic;                      -- Input from PMD to indicate presence of optical input.
      gt0_qplloutclk_in      : in  std_logic;
      gt0_qplloutrefclk_in   : in  std_logic

      );
end GigEthGtx7Core;


architecture wrapper of GigEthGtx7Core is

   attribute DowngradeIPIdentifiedWarnings: string;
   attribute DowngradeIPIdentifiedWarnings of wrapper : architecture is "yes";

   component GigEthGtx7Core_block
      port(
      -- Transceiver Interface
      ---------------------

      gtrefclk                 : in  std_logic;                           -- Very high quality clock for GT transceiver.
      gtrefclk_bufg            : in  std_logic;                           
      
      txp                  : out std_logic;                    -- Differential +ve of serial transmission from PMA to PMD.
      txn                  : out std_logic;                    -- Differential -ve of serial transmission from PMA to PMD.
      rxp                  : in std_logic;                     -- Differential +ve for serial reception from PMD to PMA.
      rxn                  : in std_logic;                     -- Differential -ve for serial reception from PMD to PMA.
      resetdone                : out std_logic;                           -- The GT transceiver has completed its reset cycle
      cplllock                : out std_logic;                           -- The GT transceiver has completed its reset cycle
      mmcm_reset              : out std_logic;         
      txoutclk                 : out std_logic;                           -- txoutclk from GT transceiver (62.5MHz)
      rxoutclk                 : out std_logic;                           -- txoutclk from GT transceiver (62.5MHz)
      userclk                  : in  std_logic;                           
      userclk2                 : in  std_logic;                           
      rxuserclk                  : in  std_logic;                          
      rxuserclk2                 : in  std_logic;                          
      independent_clock_bufg : in std_logic;               
      pma_reset                : in  std_logic;                           -- transceiver PMA reset signal
      mmcm_locked              : in  std_logic;                           -- MMCM Locked
      -- GMII Interface
      -----------------
      gmii_txd             : in std_logic_vector(7 downto 0);  -- Transmit data from client MAC.
      gmii_tx_en           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_tx_er           : in std_logic;                     -- Transmit control signal from client MAC.
      gmii_rxd             : out std_logic_vector(7 downto 0); -- Received Data to client MAC.
      gmii_rx_dv           : out std_logic;                    -- Received control signal to client MAC.
      gmii_rx_er           : out std_logic;                    -- Received control signal to client MAC.
      gmii_isolate         : out std_logic;                    -- Tristate control to electrically isolate GMII.

      -- Management: Alternative to MDIO Interface
      --------------------------------------------

      configuration_vector : in std_logic_vector(4 downto 0);  -- Alternative to MDIO interface.


      -- General IO's
      ---------------
      status_vector        : out std_logic_vector(15 downto 0); -- Core status.
      reset                : in std_logic;                     -- Asynchronous reset for entire core.
  
      signal_detect        : in std_logic;                      -- Input from PMD to indicate presence of optical input.

      gt0_qplloutclk_in      : in  std_logic;
      gt0_qplloutrefclk_in   : in  std_logic

      );
   end component;

ATTRIBUTE CORE_GENERATION_INFO : STRING;
ATTRIBUTE CORE_GENERATION_INFO OF wrapper : ARCHITECTURE IS "GigEthGtx7Core,gig_ethernet_pcs_pma_v15_1_0,{x_ipProduct=Vivado 2015.3,x_ipVendor=xilinx.com,x_ipLibrary=ip,x_ipName=gig_ethernet_pcs_pma,x_ipVersion=15.1,x_ipCoreRevision=0,x_ipLanguage=VHDL,x_ipSimLanguage=MIXED,c_elaboration_transient_dir=.,c_component_name=GigEthGtx7Core,c_family=kintex7,c_is_sgmii=false,c_use_transceiver=true,c_use_tbi=false,c_is_2_5g=false,c_use_lvds=false,c_has_an=false,c_has_mdio=false,c_has_ext_mdio=false,c_sgmii_phy_mode=false,c_dynamic_switching=false,c_sgmii_fabric_buffer=true,c_1588=0,gt_rx_byte_width=1,C_EMAC_IF_TEMAC=true,C_PHYADDR=1,EXAMPLE_SIMULATION=0,c_support_level=false,c_sub_core_name=GigEthGtx7Core_gt,c_transceiver_type=GTXE2,c_transceivercontrol=false,c_xdevicefamily=xc7k325t,c_gt_dmonitorout_width=8,c_gt_drpaddr_width=9,c_gt_txdiffctrl_width=4,c_gt_rxmonitorout_width=7,c_num_of_lanes=1,c_refclkrate=125,c_drpclkrate=50.0}";
ATTRIBUTE X_CORE_INFO : STRING;
ATTRIBUTE X_CORE_INFO OF wrapper: ARCHITECTURE IS "gig_ethernet_pcs_pma_v15_1_0,Vivado 2015.3";

begin



   U0 : GigEthGtx7Core_block
      port map(
      -- Transceiver Interface
      ---------------------

      gtrefclk                 => gtrefclk,
      gtrefclk_bufg            => gtrefclk_bufg,
      txp                      => txp,
      txn                      => txn,
      rxp                      => rxp,
      rxn                      => rxn,
      resetdone                => resetdone,
      cplllock                 => cplllock,                           -- The GT transceiver has completed its reset cycle
      mmcm_reset               => mmcm_reset,
      txoutclk                 => txoutclk,
      rxoutclk                 => rxoutclk,
      userclk                  => userclk,
      userclk2                 => userclk2,
      rxuserclk                => rxuserclk,
      rxuserclk2               => rxuserclk2,
          independent_clock_bufg => independent_clock_bufg,
      pma_reset                => pma_reset,
      mmcm_locked              => mmcm_locked,
      -- GMII Interface
      -----------------
      gmii_txd                 => gmii_txd,
      gmii_tx_en               => gmii_tx_en,
      gmii_tx_er               => gmii_tx_er,
      gmii_rxd                 => gmii_rxd,
      gmii_rx_dv               => gmii_rx_dv,
      gmii_rx_er               => gmii_rx_er,
      gmii_isolate             => gmii_isolate,

      -- Management: Alternative to MDIO Interface
      --------------------------------------------

      configuration_vector     => configuration_vector,


      -- General IO's
      ---------------
      status_vector             => status_vector,
      reset                     => reset,

   
   

          signal_detect        => signal_detect,

      gt0_qplloutclk_in      => gt0_qplloutclk_in,
      gt0_qplloutrefclk_in   => gt0_qplloutrefclk_in

      );
end wrapper;

