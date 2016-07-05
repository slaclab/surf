-- (c) Copyright 1995-2016 Xilinx, Inc. All rights reserved.
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
-- DO NOT MODIFY THIS FILE.

-- IP VLNV: xilinx.com:ip:gig_ethernet_pcs_pma:15.2
-- IP Revision: 0

-- The following code must appear in the VHDL architecture header.

------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
COMPONENT GigEthGthUltraScaleCore
  PORT (
    gtrefclk : IN STD_LOGIC;
    txn : OUT STD_LOGIC;
    txp : OUT STD_LOGIC;
    rxn : IN STD_LOGIC;
    rxp : IN STD_LOGIC;
    independent_clock_bufg : IN STD_LOGIC;
    txoutclk : OUT STD_LOGIC;
    rxoutclk : OUT STD_LOGIC;
    resetdone : OUT STD_LOGIC;
    cplllock : OUT STD_LOGIC;
    mmcm_reset : OUT STD_LOGIC;
    userclk : IN STD_LOGIC;
    userclk2 : IN STD_LOGIC;
    pma_reset : IN STD_LOGIC;
    mmcm_locked : IN STD_LOGIC;
    rxuserclk : IN STD_LOGIC;
    rxuserclk2 : IN STD_LOGIC;
    gmii_txd : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_tx_en : IN STD_LOGIC;
    gmii_tx_er : IN STD_LOGIC;
    gmii_rxd : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    gmii_rx_dv : OUT STD_LOGIC;
    gmii_rx_er : OUT STD_LOGIC;
    gmii_isolate : OUT STD_LOGIC;
    configuration_vector : IN STD_LOGIC_VECTOR(4 DOWNTO 0);
    status_vector : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
    reset : IN STD_LOGIC;
    signal_detect : IN STD_LOGIC
  );
END COMPONENT;
-- COMP_TAG_END ------ End COMPONENT Declaration ------------

-- The following code must appear in the VHDL architecture
-- body. Substitute your own instance name and net names.

------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
your_instance_name : GigEthGthUltraScaleCore
  PORT MAP (
    gtrefclk => gtrefclk,
    txn => txn,
    txp => txp,
    rxn => rxn,
    rxp => rxp,
    independent_clock_bufg => independent_clock_bufg,
    txoutclk => txoutclk,
    rxoutclk => rxoutclk,
    resetdone => resetdone,
    cplllock => cplllock,
    mmcm_reset => mmcm_reset,
    userclk => userclk,
    userclk2 => userclk2,
    pma_reset => pma_reset,
    mmcm_locked => mmcm_locked,
    rxuserclk => rxuserclk,
    rxuserclk2 => rxuserclk2,
    gmii_txd => gmii_txd,
    gmii_tx_en => gmii_tx_en,
    gmii_tx_er => gmii_tx_er,
    gmii_rxd => gmii_rxd,
    gmii_rx_dv => gmii_rx_dv,
    gmii_rx_er => gmii_rx_er,
    gmii_isolate => gmii_isolate,
    configuration_vector => configuration_vector,
    status_vector => status_vector,
    reset => reset,
    signal_detect => signal_detect
  );
-- INST_TAG_END ------ End INSTANTIATION Template ---------

-- You must compile the wrapper file GigEthGthUltraScaleCore.vhd when simulating
-- the core, GigEthGthUltraScaleCore. When compiling the wrapper file, be sure to
-- reference the VHDL simulation library.

