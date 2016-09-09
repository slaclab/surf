//------------------------------------------------------------------------------
//  (c) Copyright 2013-2015 Xilinx, Inc. All rights reserved.
//
//  This file contains confidential and proprietary information
//  of Xilinx, Inc. and is protected under U.S. and
//  international copyright and other intellectual property
//  laws.
//
//  DISCLAIMER
//  This disclaimer is not a license and does not grant any
//  rights to the materials distributed herewith. Except as
//  otherwise provided in a valid license issued to you by
//  Xilinx, and to the maximum extent permitted by applicable
//  law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
//  WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
//  AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
//  BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
//  INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
//  (2) Xilinx shall not be liable (whether in contract or tort,
//  including negligence, or under any other theory of
//  liability) for any loss or damage of any kind or nature
//  related to, arising under or in connection with these
//  materials, including for any direct, or any indirect,
//  special, incidental, or consequential loss or damage
//  (including loss of data, profits, goodwill, or any type of
//  loss or damage suffered as a result of any action brought
//  by a third party) even if such damage or loss was
//  reasonably foreseeable or Xilinx had been advised of the
//  possibility of the same.
//
//  CRITICAL APPLICATIONS
//  Xilinx products are not designed or intended to be fail-
//  safe, or for use in any application requiring fail-safe
//  performance, such as life-support or safety devices or
//  systems, Class III medical devices, nuclear facilities,
//  applications related to the deployment of airbags, or any
//  other applications that could lead to death, personal
//  injury, or severe property or environmental damage
//  (individually and collectively, "Critical
//  Applications"). Customer assumes the sole risk and
//  liability of any use of Xilinx products in Critical
//  Applications, subject only to applicable laws and
//  regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
//  PART OF THIS FILE AT ALL TIMES.
//------------------------------------------------------------------------------

// ***************************
// * DO NOT MODIFY THIS FILE *
// ***************************

`timescale 1ps/1ps

`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_CHANNELS 192
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_COMMONS 48
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CM C_TOTAL_NUM_COMMONS
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH C_TOTAL_NUM_CHANNELS
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM C_COMMON_SCALING_FACTOR
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_INCLUDE_CPLL_CAL__EXCLUDE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_INCLUDE_CPLL_CAL__INCLUDE 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_INCLUDE_CPLL_CAL__DEPENDENT 2
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RESET_CONTROLLER__CORE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RESET_CONTROLLER__EXAMPLE_DESIGN 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_USER_DATA_WIDTH_SIZING__CORE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_USER_DATA_WIDTH_SIZING__EXAMPLE_DESIGN 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RX_BUFFER_BYPASS_CONTROLLER__CORE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RX_BUFFER_BYPASS_CONTROLLER__EXAMPLE_DESIGN 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RX_USER_CLOCKING__CORE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RX_USER_CLOCKING__EXAMPLE_DESIGN 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_TX_BUFFER_BYPASS_CONTROLLER__CORE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_TX_BUFFER_BYPASS_CONTROLLER__EXAMPLE_DESIGN 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_TX_USER_CLOCKING__CORE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_TX_USER_CLOCKING__EXAMPLE_DESIGN 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__SINGLE_INSTANCE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__PER_CHANNEL 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFBYPASS_MODE__AUTO 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFBYPASS_MODE__MANUAL 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_BYPASS_INSTANCE_CTRL__SINGLE_INSTANCE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_BYPASS_INSTANCE_CTRL__PER_CHANNEL 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_MODE__BYPASS 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_MODE__USE 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__RAW 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__8B10B 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__64B66B 2
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__64B66B_CAUI 3
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__64B66B_ASYNC 4
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__64B66B_ASYNC_CAUI 5
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__64B67B 6
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__64B67B_CAUI 7
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__128B130B 10
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_ENABLE__DISABLED 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_ENABLE__ENABLED 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL 2
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_CONTENTS__BUFG_GT 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_CONTENTS__BUFG 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_CONTENTS__MMCM 2
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_INSTANCE_CTRL__PER_CHANNEL 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__RXOUTCLK 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__IBUFDS 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__TXOUTCLK 2
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TXPROGDIV_FREQ_ENABLE__DISABLED 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TXPROGDIV_FREQ_ENABLE__ENABLED 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TXPROGDIV_FREQ_SOURCE__QPLL0 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TXPROGDIV_FREQ_SOURCE__QPLL1 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TXPROGDIV_FREQ_SOURCE__CPLL 2
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFBYPASS_MODE__AUTO 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFBYPASS_MODE__MANUAL 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_BYPASS_INSTANCE_CTRL__SINGLE_INSTANCE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_BYPASS_INSTANCE_CTRL__PER_CHANNEL 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_MODE__BYPASS 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_MODE__USE 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__RAW 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__8B10B 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__64B66B 2
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__64B66B_CAUI 3
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__64B66B_ASYNC 4
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__64B66B_ASYNC_CAUI 5
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__64B67B 6
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__64B67B_CAUI 7
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__128B130B 10
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_ENABLE__DISABLED 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_ENABLE__ENABLED 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL 2
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_CONTENTS__BUFG_GT 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_CONTENTS__BUFG 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_CONTENTS__MMCM 2
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_INSTANCE_CTRL__PER_CHANNEL 1
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_SOURCE__TXOUTCLK 0
`define GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_SOURCE__IBUFDS 1

module GigEthGthUltraScaleCore_gt_gtwizard_gthe3 #(

  parameter [191:0] C_CHANNEL_ENABLE                          = 192'b1,
  parameter integer C_COMMON_SCALING_FACTOR                   = 1,
  parameter real    C_CPLL_VCO_FREQUENCY                      = 5156.25,
  parameter real    C_FREERUN_FREQUENCY                       = 200,
  parameter integer C_GT_REV                                  = 17,
  parameter integer C_INCLUDE_CPLL_CAL                        = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_INCLUDE_CPLL_CAL__DEPENDENT,
  parameter integer C_LOCATE_RESET_CONTROLLER                 = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RESET_CONTROLLER__CORE,
  parameter integer C_LOCATE_USER_DATA_WIDTH_SIZING           = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_USER_DATA_WIDTH_SIZING__CORE,
  parameter integer C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER      = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RX_BUFFER_BYPASS_CONTROLLER__CORE,
  parameter integer C_LOCATE_RX_USER_CLOCKING                 = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RX_USER_CLOCKING__EXAMPLE_DESIGN,
  parameter integer C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER      = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_TX_BUFFER_BYPASS_CONTROLLER__CORE,
  parameter integer C_LOCATE_TX_USER_CLOCKING                 = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_TX_USER_CLOCKING__EXAMPLE_DESIGN,
  parameter integer C_RESET_CONTROLLER_INSTANCE_CTRL          = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__SINGLE_INSTANCE,
  parameter integer C_RX_BUFFBYPASS_MODE                      = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFBYPASS_MODE__AUTO,
  parameter integer C_RX_BUFFER_BYPASS_INSTANCE_CTRL          = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_BYPASS_INSTANCE_CTRL__SINGLE_INSTANCE,
  parameter integer C_RX_BUFFER_MODE                          = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_MODE__USE,
  parameter integer C_RX_DATA_DECODING                        = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_DATA_DECODING__RAW,
  parameter integer C_RX_ENABLE                               = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_ENABLE__ENABLED,
  parameter integer C_RX_INT_DATA_WIDTH                       = 32,
  parameter real    C_RX_LINE_RATE                            = 10.3125,
  parameter integer C_RX_MASTER_CHANNEL_IDX                   = 0,
  parameter integer C_RX_OUTCLK_BUFG_GT_DIV                   = 1,
  parameter integer C_RX_PLL_TYPE                             = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0,
  parameter integer C_RX_USER_CLOCKING_CONTENTS               = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_CONTENTS__BUFG_GT,
  parameter integer C_RX_USER_CLOCKING_INSTANCE_CTRL          = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE,
  parameter integer C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 = 1,
  parameter integer C_RX_USER_CLOCKING_SOURCE                 = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__RXOUTCLK,
  parameter integer C_RX_USER_DATA_WIDTH                      = 32,
  parameter integer C_TOTAL_NUM_CHANNELS                      = 1,
  parameter integer C_TOTAL_NUM_COMMONS                       = 1,
  parameter integer C_TXPROGDIV_FREQ_ENABLE                   = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TXPROGDIV_FREQ_ENABLE__DISABLED,
  parameter integer C_TXPROGDIV_FREQ_SOURCE                   = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TXPROGDIV_FREQ_SOURCE__QPLL0,
  parameter integer C_TX_BUFFBYPASS_MODE                      = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFBYPASS_MODE__AUTO,
  parameter integer C_TX_BUFFER_BYPASS_INSTANCE_CTRL          = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_BYPASS_INSTANCE_CTRL__SINGLE_INSTANCE,
  parameter integer C_TX_BUFFER_MODE                          = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_MODE__USE,
  parameter integer C_TX_DATA_ENCODING                        = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__RAW,
  parameter integer C_TX_ENABLE                               = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_ENABLE__ENABLED,
  parameter integer C_TX_INT_DATA_WIDTH                       = 32,
  parameter integer C_TX_MASTER_CHANNEL_IDX                   = 0,
  parameter integer C_TX_OUTCLK_BUFG_GT_DIV                   = 1,
  parameter integer C_TX_PLL_TYPE                             = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0,
  parameter integer C_TX_USER_CLOCKING_CONTENTS               = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_CONTENTS__BUFG_GT,
  parameter integer C_TX_USER_CLOCKING_INSTANCE_CTRL          = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE,
  parameter integer C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2 = 1,
  parameter integer C_TX_USER_CLOCKING_SOURCE                 = `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_SOURCE__TXOUTCLK,
  parameter integer C_TX_USER_DATA_WIDTH                      = 32

)(

  // Transmitter user clocking network helper block ports
  input  wire [(C_TX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_tx_reset_in,
  input  wire [(C_TX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_tx_active_in,
  output wire [(C_TX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_tx_srcclk_out,
  output wire [(C_TX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_tx_usrclk_out,
  output wire [(C_TX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_tx_usrclk2_out,
  output wire [(C_TX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_tx_active_out,

  // Receiver user clocking network helper block ports
  input  wire [(C_RX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_rx_reset_in,
  input  wire [(C_RX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_rx_active_in,
  output wire [(C_RX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_rx_srcclk_out,
  output wire [(C_RX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_rx_usrclk_out,
  output wire [(C_RX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_rx_usrclk2_out,
  output wire [(C_RX_USER_CLOCKING_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_userclk_rx_active_out,

  // Transmitter buffer bypass controller helper block ports
  input  wire [(C_TX_BUFFER_BYPASS_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_buffbypass_tx_reset_in,
  input  wire [(C_TX_BUFFER_BYPASS_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_buffbypass_tx_start_user_in,
  output wire [(C_TX_BUFFER_BYPASS_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_buffbypass_tx_done_out,
  output wire [(C_TX_BUFFER_BYPASS_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_buffbypass_tx_error_out,

  // Receiver buffer bypass controller helper block ports
  input  wire [(C_RX_BUFFER_BYPASS_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_buffbypass_rx_reset_in,
  input  wire [(C_RX_BUFFER_BYPASS_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_buffbypass_rx_start_user_in,
  output wire [(C_RX_BUFFER_BYPASS_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_buffbypass_rx_done_out,
  output wire [(C_RX_BUFFER_BYPASS_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_buffbypass_rx_error_out,

  // Reset controller helper block ports
  input  wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_clk_freerun_in,
  input  wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_all_in,
  input  wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_tx_pll_and_datapath_in,
  input  wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_tx_datapath_in,
  input  wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_rx_pll_and_datapath_in,
  input  wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_rx_datapath_in,
  input  wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_tx_done_in,
  input  wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_rx_done_in,
  input  wire [                                  (`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM-1):0] gtwiz_reset_qpll0lock_in,
  input  wire [                                  (`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM-1):0] gtwiz_reset_qpll1lock_in,
  output wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_rx_cdr_stable_out,
  output wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_tx_done_out,
  output wire [(C_RESET_CONTROLLER_INSTANCE_CTRL*(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1)):0] gtwiz_reset_rx_done_out,
  output wire [                                  (`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM-1):0] gtwiz_reset_qpll0reset_out,
  output wire [                                  (`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM-1):0] gtwiz_reset_qpll1reset_out,

  // CPLL calibration block ports
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 18)-1:0] gtwiz_gthe3_cpll_cal_txoutclk_period_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 18)-1:0] gtwiz_gthe3_cpll_cal_cnt_tol_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtwiz_gthe3_cpll_cal_bufg_ce_in,

  // Transmitter user data width sizing helper block ports
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*C_TX_USER_DATA_WIDTH)-1:0] gtwiz_userdata_tx_in,

  // Receiver user data width sizing helper block ports
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*C_RX_USER_DATA_WIDTH)-1:0] gtwiz_userdata_rx_out,

  // Transceiver common block ports
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] bgbypassb_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] bgmonitorenb_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] bgpdb_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  5)-1:0] bgrcalovrd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] bgrcalovrdenb_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  9)-1:0] drpaddr_common_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] drpclk_common_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 16)-1:0] drpdi_common_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] drpen_common_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] drpwe_common_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtgrefclk0_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtgrefclk1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtnorthrefclk00_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtnorthrefclk01_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtnorthrefclk10_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtnorthrefclk11_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtrefclk00_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtrefclk01_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtrefclk10_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtrefclk11_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtsouthrefclk00_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtsouthrefclk01_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtsouthrefclk10_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] gtsouthrefclk11_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  8)-1:0] pmarsvd0_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  8)-1:0] pmarsvd1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0clkrsvd0_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0clkrsvd1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0lockdetclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0locken_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0pd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  3)-1:0] qpll0refclksel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0reset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1clkrsvd0_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1clkrsvd1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1lockdetclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1locken_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1pd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  3)-1:0] qpll1refclksel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1reset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  8)-1:0] qpllrsvd1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  5)-1:0] qpllrsvd2_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  5)-1:0] qpllrsvd3_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  8)-1:0] qpllrsvd4_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] rcalenb_in,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 16)-1:0] drpdo_common_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] drprdy_common_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  8)-1:0] pmarsvdout0_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  8)-1:0] pmarsvdout1_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0fbclklost_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0lock_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0outclk_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0outrefclk_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll0refclklost_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1fbclklost_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1lock_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1outclk_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1outrefclk_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] qpll1refclklost_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  8)-1:0] qplldmonitor0_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  8)-1:0] qplldmonitor1_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] refclkoutmonitor0_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  1)-1:0] refclkoutmonitor1_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  2)-1:0] rxrecclk0_sel_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*  2)-1:0] rxrecclk1_sel_out,

  // Transceiver channel block ports
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cfgreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] clkrsvd0_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] clkrsvd1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cplllockdetclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cplllocken_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllpd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] cpllrefclksel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] dmonfiforeset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] dmonitorclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  9)-1:0] drpaddr_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drpclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] drpdi_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drpen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drpwe_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphicaldone_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphicalstart_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphidrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphidwren_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphixrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphixwren_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] eyescanmode_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] eyescanreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] eyescantrigger_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtgrefclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gthrxn_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gthrxp_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtnorthrefclk0_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtnorthrefclk1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtrefclk0_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtrefclk1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtresetsel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] gtrsvd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtrxreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtsouthrefclk0_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtsouthrefclk1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gttxreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] loopback_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] lpbkrxtxseren_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] lpbktxrxseren_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieeqrxeqadaptdone_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcierstidle_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pciersttxsyncstart_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieuserratedone_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] pcsrsvdin_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] pcsrsvdin2_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] pmarsvdin_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] qpll0clk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] qpll0refclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] qpll1clk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] qpll1refclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] resetovrd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rstclkentx_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rx8b10ben_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxbufreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrfreqreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrhold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrresetrsv_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchbonden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] rxchbondi_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxchbondlevel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchbondmaster_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchbondslave_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcommadeten_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxdfeagcctrl_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfeagchold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfeagcovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfelfhold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfelfovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfelpmreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap10hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap10ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap11hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap11ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap12hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap12ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap13hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap13ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap14hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap14ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap15hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap15ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap2hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap2ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap3hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap3ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap4hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap4ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap5hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap5ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap6hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap6ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap7hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap7ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap8hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap8ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap9hold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap9ovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfeuthold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfeutovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfevphold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfevpovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfevsen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfexyden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlybypass_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlyen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlyovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlysreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxelecidlemode_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxgearboxslip_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlatclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmgchold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmgcovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmhfhold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmhfovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmlfhold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmlfklovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmoshold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmosovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxmcommaalignen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxmonitorsel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoobreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoscalreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoshold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  4)-1:0] rxosintcfg_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosinten_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosinthold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintstrobe_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosinttestovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxoutclksel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpcommaalignen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpcsreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxpd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphalign_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphalignen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphdlypd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphdlyreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxpllclksel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpmareset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpolarity_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprbscntreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  4)-1:0] rxprbssel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprogdivreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxqpien_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxrate_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxratemode_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslide_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslipoutclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslippma_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncallin_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncin_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncmode_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxsysclksel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxuserrdy_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxusrclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxusrclk2_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] sigvalidclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 20)-1:0] tstin_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] tx8b10bbypass_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] tx8b10ben_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txbufdiffctrl_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txcominit_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txcomsas_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txcomwake_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] txctrl0_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] txctrl1_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] txctrl2_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*128)-1:0] txdata_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] txdataextendrsvd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdeemph_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdetectrx_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  4)-1:0] txdiffctrl_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdiffpd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlybypass_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlyen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlyhold_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlyovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlysreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlyupdown_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txelecidle_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  6)-1:0] txheader_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txinhibit_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txlatclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  7)-1:0] txmaincursor_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txmargin_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txoutclksel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpcsreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] txpd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpdelecidlemode_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphalign_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphalignen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphdlypd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphdlyreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphdlytstclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphinit_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpippmen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpippmovrden_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpippmpd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpippmsel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] txpippmstepsize_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpisopd_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] txpllclksel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpmareset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpolarity_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] txpostcursor_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpostcursorinv_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txprbsforceerr_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  4)-1:0] txprbssel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] txprecursor_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txprecursorinv_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txprogdivreset_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpibiasen_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpistrongpdown_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpiweakpup_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txrate_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txratemode_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  7)-1:0] txsequence_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txswing_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncallin_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncin_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncmode_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] txsysclksel_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txuserrdy_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txusrclk_in,
  input  wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txusrclk2_in,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] bufgtce_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] bufgtcemask_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  9)-1:0] bufgtdiv_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] bufgtreset_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] bufgtrstmask_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllfbclklost_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cplllock_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllrefclklost_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 17)-1:0] dmonitorout_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] drpdo_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drprdy_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] eyescandataerror_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gthtxn_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gthtxp_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtpowergood_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtrefclkmonitor_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcierategen3_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcierateidle_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] pcierateqpllpd_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] pcierateqpllreset_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pciesynctxsyncdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieusergen3rdy_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieuserphystatusrst_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieuserratestart_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 12)-1:0] pcsrsvdout_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] phystatus_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] pinrsrvdas_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] resetexception_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxbufstatus_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxbyteisaligned_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxbyterealign_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrlock_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrphdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchanbondseq_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchanisaligned_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchanrealign_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] rxchbondo_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxclkcorcnt_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcominitdet_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcommadet_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcomsasdet_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcomwakedet_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] rxctrl0_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] rxctrl1_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] rxctrl2_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] rxctrl3_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*128)-1:0] rxdata_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] rxdataextendrsvd_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxdatavalid_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlysresetdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxelecidle_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  6)-1:0] rxheader_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxheadervalid_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  7)-1:0] rxmonitorout_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintstarted_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintstrobedone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintstrobestarted_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoutclk_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoutclkfabric_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoutclkpcs_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphaligndone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphalignerr_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpmaresetdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprbserr_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprbslocked_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprgdivresetdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxqpisenn_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxqpisenp_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxratedone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxrecclkout_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxresetdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsliderdy_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslipdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslipoutclkrdy_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslippmardy_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxstartofseq_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxstatus_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncout_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxvalid_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] txbufstatus_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txcomfinish_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlysresetdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txoutclk_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txoutclkfabric_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txoutclkpcs_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphaligndone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphinitdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpmaresetdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txprgdivresetdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpisenn_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpisenp_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txratedone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txresetdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncdone_out,
  output wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncout_out

);


  // ================================================================================================================
  // LOCAL PARAMETERS AND FUNCTIONS
  // ================================================================================================================

  // ----------------------------------------------------------------------------------------------------------------
  // Declare and initialize local parameters used for HDL generation
  // ----------------------------------------------------------------------------------------------------------------
  localparam [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_COMMONS-1:0] P_COMMON_ENABLE = f_pop_cm_en(0);
  localparam integer P_TX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(C_TX_MASTER_CHANNEL_IDX);
  localparam integer P_RX_MASTER_CH_PACKED_IDX = f_calc_pk_mc_idx(C_RX_MASTER_CHANNEL_IDX);
  localparam integer P_USE_CPLL_CAL                   = (C_GT_REV == 11 || C_GT_REV == 12 || C_GT_REV == 14 || C_GT_REV == 16) ? 1 : 0;
  localparam [15:0] P_CPLL_CAL_FREQ_COUNT_WINDOW      = 16'd16000;
  localparam [17:0] P_CPLL_CAL_TXOUTCLK_PERIOD        = (C_CPLL_VCO_FREQUENCY/20) * (P_CPLL_CAL_FREQ_COUNT_WINDOW/(4*C_FREERUN_FREQUENCY));
  localparam [15:0] P_CPLL_CAL_WAIT_DEASSERT_CPLLPD   = 16'd256;
  localparam [17:0] P_CPLL_CAL_TXOUTCLK_PERIOD_DIV100 = (C_CPLL_VCO_FREQUENCY/20) * (P_CPLL_CAL_FREQ_COUNT_WINDOW/(400*C_FREERUN_FREQUENCY));
  localparam [25:0] P_CDR_TIMEOUT_FREERUN_CYC         = (37000 * C_FREERUN_FREQUENCY) / C_RX_LINE_RATE;


  // ----------------------------------------------------------------------------------------------------------------
  // Functions used for HDL generation
  // ----------------------------------------------------------------------------------------------------------------

  // Function to populate a bit mapping of enabled transceiver common blocks to transceiver quads
  function [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_COMMONS-1:0] f_pop_cm_en (
    input integer in_null
  );
  begin : main_f_pop_cm_en
    integer i;
    reg [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_COMMONS-1:0] tmp;
    for (i = 0; i < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_CHANNELS; i = i + 4) begin
      if ((C_CHANNEL_ENABLE[i]   ==  1'b1) ||
          (C_CHANNEL_ENABLE[i+1] ==  1'b1) ||
          (C_CHANNEL_ENABLE[i+2] ==  1'b1) ||
          (C_CHANNEL_ENABLE[i+3] ==  1'b1))
        tmp[i/4] = 1'b1;
      else
        tmp[i/4] = 1'b0;
    end
    f_pop_cm_en = tmp;
  end
  endfunction

  // Function to calculate a pointer to a master channel's packed index
  function integer f_calc_pk_mc_idx (
    input integer idx_mc
  );
  begin : main_f_calc_pk_mc_idx
    integer i, j;
    integer tmp;
    j = 0;
    for (i = 0; i < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_CHANNELS; i = i + 1) begin
      if (C_CHANNEL_ENABLE[i] == 1'b1) begin
        if (i == idx_mc)
          tmp = j;
        else
          j = j + 1;
      end
    end
    f_calc_pk_mc_idx = tmp;
  end
  endfunction

  // Function to calculate the upper bound of a transceiver common-related signal within a packed vector, for a given
  // signal width and unpacked common index
  function integer f_ub_cm (
    input integer width,
    input integer index
  );
  begin : main_f_ub_cm
    integer i, j;
    j = 0;
    for (i = 0; i <= index; i = i + 4) begin
      if (C_CHANNEL_ENABLE[i]   == 1'b1 ||
          C_CHANNEL_ENABLE[i+1] == 1'b1 ||
          C_CHANNEL_ENABLE[i+2] == 1'b1 ||
          C_CHANNEL_ENABLE[i+3] == 1'b1)
        j = j + 1;
    end
    f_ub_cm = (width * j) - 1;
  end
  endfunction

  // Function to calculate the lower bound of a transceiver common-related signal within a packed vector, for a given
  // signal width and unpacked common index
  function integer f_lb_cm (
    input integer width,
    input integer index
  );
  begin : main_f_lb_cm
    integer i, j;
    j = 0;
    for (i = 0; i < index; i = i + 4) begin
      if (C_CHANNEL_ENABLE[i]   == 1'b1 ||
          C_CHANNEL_ENABLE[i+1] == 1'b1 ||
          C_CHANNEL_ENABLE[i+2] == 1'b1 ||
          C_CHANNEL_ENABLE[i+3] == 1'b1)
        j = j + 1;
    end
    f_lb_cm = (width * j);
  end
  endfunction

  // Function to calculate the number of transceiver channels enabled within a given transceiver quad
  function integer f_num_ch_in_quad (
    input integer chan_en_idx_lb
  );
  begin : main_f_num_ch_in_quad
    f_num_ch_in_quad =
      ((C_CHANNEL_ENABLE[chan_en_idx_lb+3] == 1'b1 ? 1 : 0) +
       (C_CHANNEL_ENABLE[chan_en_idx_lb+2] == 1'b1 ? 1 : 0) +
       (C_CHANNEL_ENABLE[chan_en_idx_lb+1] == 1'b1 ? 1 : 0) +
       (C_CHANNEL_ENABLE[chan_en_idx_lb]   == 1'b1 ? 1 : 0));
  end
  endfunction

  // Function to calculate the upper bound of a transceiver channel-related signal within a packed vector, for a given
  // signal width and unpacked channel index
  function integer f_ub_ch (
    input integer width,
    input integer index
  );
  begin : main_f_ub_ch
    integer i, j;
    j = 0;
    for (i = 0; i <= index; i = i + 1) begin
      if (C_CHANNEL_ENABLE[i] == 1'b1)
        j = j + 1;
    end
    f_ub_ch = (width * j) - 1;
  end
  endfunction

  // Function to calculate the lower bound of a transceiver channel-related signal within a packed vector, for a given
  // signal width and unpacked channel index
  function integer f_lb_ch (
    input integer width,
    input integer index
  );
  begin : main_f_lb_ch
    integer i, j;
    j = 0;
    for (i = 0; i < index; i = i + 1) begin
      if (C_CHANNEL_ENABLE[i] == 1'b1)
        j = j + 1;
    end
    f_lb_ch = (width * j);
  end
  endfunction

  // Function to calculate the packed vector index of a transceiver common, provided the packed vector index of the
  // associated transceiver channel
  function integer f_idx_cm (
    input integer index
  );
  begin : main_f_idx_cm
    integer i, j, k, flag, result;
    j    = 0;
    k    = 0;
    flag = 0;
    for (i = 0; (i < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_CHANNELS) && (flag == 0); i = i + 4) begin
      if (C_CHANNEL_ENABLE[i]   == 1'b1 ||
          C_CHANNEL_ENABLE[i+1] == 1'b1 ||
          C_CHANNEL_ENABLE[i+2] == 1'b1 ||
          C_CHANNEL_ENABLE[i+3] == 1'b1) begin
        k = k + 1;
        if (C_CHANNEL_ENABLE[i+3] == 1'b1)
          j = j + 1;
        if (C_CHANNEL_ENABLE[i+2] == 1'b1)
          j = j + 1;
        if (C_CHANNEL_ENABLE[i+1] == 1'b1)
          j = j + 1;
        if (C_CHANNEL_ENABLE[i]   == 1'b1)
          j = j + 1;
      end

      if (j >= (index + 1)) begin
        flag   = 1;
        result = k;
      end
    end
    f_idx_cm = result - 1;
  end
  endfunction

  // Function to calculate the packed vector index of the upper bound transceiver channel which is associated with the
  // provided transceiver common packed vector index
  function integer f_idx_ch_ub (
    input integer index
  );
  begin : main_f_idx_ch_ub
    integer i, j, k, flag, result;
    j    = 0;
    k    = 0;
    flag = 0;
    for (i = 0; (i < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_CHANNELS) && (flag == 0); i = i + 4) begin

      if (C_CHANNEL_ENABLE[i]   == 1'b1 ||
          C_CHANNEL_ENABLE[i+1] == 1'b1 ||
          C_CHANNEL_ENABLE[i+2] == 1'b1 ||
          C_CHANNEL_ENABLE[i+3] == 1'b1) begin
        k = k + 1;
        if (C_CHANNEL_ENABLE[i]   == 1'b1)
          j = j + 1;
        if (C_CHANNEL_ENABLE[i+1] == 1'b1)
          j = j + 1;
        if (C_CHANNEL_ENABLE[i+2] == 1'b1)
          j = j + 1;
        if (C_CHANNEL_ENABLE[i+3] == 1'b1)
          j = j + 1;
        if (k == index + 1) begin
          flag   = 1;
          result = j;
        end
      end

    end
    f_idx_ch_ub = result - 1;
  end
  endfunction

  // Function to calculate the packed vector index of the lower bound transceiver channel which is associated with the
  // provided transceiver common packed vector index
  function integer f_idx_ch_lb (
    input integer index
  );
  begin : main_f_idx_ch_lb
    integer i, j, k, flag, result;
    j    = 0;
    k    = 0;
    flag = 0;
    for (i = 0; (i < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_CHANNELS) && (flag == 0); i = i + 4) begin

      if (C_CHANNEL_ENABLE[i]   == 1'b1 ||
          C_CHANNEL_ENABLE[i+1] == 1'b1 ||
          C_CHANNEL_ENABLE[i+2] == 1'b1 ||
          C_CHANNEL_ENABLE[i+3] == 1'b1) begin
        k = k + 1;
        if (k == index + 1) begin
          flag   = 1;
          result = j + 1;
        end
        else begin
          if (C_CHANNEL_ENABLE[i]   == 1'b1)
            j = j + 1;
          if (C_CHANNEL_ENABLE[i+1] == 1'b1)
            j = j + 1;
          if (C_CHANNEL_ENABLE[i+2] == 1'b1)
            j = j + 1;
          if (C_CHANNEL_ENABLE[i+3] == 1'b1)
            j = j + 1;
        end
      end

    end
    f_idx_ch_lb = result - 1;
  end
  endfunction


  // Begin main body of generated code
  generate if (1) begin : gen_gtwizard_gthe3

    // ================================================================================================================
    // TRANSCEIVER BLOCKS
    // ================================================================================================================

    // ----------------------------------------------------------------------------------------------------------------
    // Transceiver common block declarations, assignments, and primitive wrapper conditional generation
    // ----------------------------------------------------------------------------------------------------------------

    // Declare the signal vectors used to map to transceiver common-related ports
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] bgbypassb_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] bgmonitorenb_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] bgpdb_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 5)-1:0] bgrcalovrd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] bgrcalovrdenb_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 9)-1:0] drpaddr_common_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] drpclk_common_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*16)-1:0] drpdi_common_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] drpen_common_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] drpwe_common_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtgrefclk0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtgrefclk1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtnorthrefclk00_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtnorthrefclk01_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtnorthrefclk10_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtnorthrefclk11_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtrefclk00_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtrefclk01_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtrefclk10_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtrefclk11_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtsouthrefclk00_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtsouthrefclk01_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtsouthrefclk10_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] gtsouthrefclk11_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 8)-1:0] pmarsvd0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 8)-1:0] pmarsvd1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0clkrsvd0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0clkrsvd1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0lockdetclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0locken_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0pd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 3)-1:0] qpll0refclksel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0reset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1clkrsvd0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1clkrsvd1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1lockdetclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1locken_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1pd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 3)-1:0] qpll1refclksel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1reset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 8)-1:0] qpllrsvd1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 5)-1:0] qpllrsvd2_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 5)-1:0] qpllrsvd3_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 8)-1:0] qpllrsvd4_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] rcalenb_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM*16)-1:0] drpdo_common_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] drprdy_common_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 8)-1:0] pmarsvdout0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 8)-1:0] pmarsvdout1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0fbclklost_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0lock_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0outclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0outrefclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll0refclklost_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1fbclklost_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1lock_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1outclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1outrefclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] qpll1refclklost_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 8)-1:0] qplldmonitor0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 8)-1:0] qplldmonitor1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] refclkoutmonitor0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 1)-1:0] refclkoutmonitor1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 2)-1:0] rxrecclk0_sel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM* 2)-1:0] rxrecclk1_sel_int;

    // Assign transceiver common-related inputs to the corresponding internal signal vectors
    // Note: commented assignments are replaced by assignments associated with helper blocks, later in this module
    assign bgbypassb_int         = bgbypassb_in;
    assign bgmonitorenb_int      = bgmonitorenb_in;
    assign bgpdb_int             = bgpdb_in;
    assign bgrcalovrd_int        = bgrcalovrd_in;
    assign bgrcalovrdenb_int     = bgrcalovrdenb_in;
    assign drpaddr_common_int    = drpaddr_common_in;
    assign drpclk_common_int     = drpclk_common_in;
    assign drpdi_common_int      = drpdi_common_in;
    assign drpen_common_int      = drpen_common_in;
    assign drpwe_common_int      = drpwe_common_in;
    assign gtgrefclk0_int        = gtgrefclk0_in;
    assign gtgrefclk1_int        = gtgrefclk1_in;
    assign gtnorthrefclk00_int   = gtnorthrefclk00_in;
    assign gtnorthrefclk01_int   = gtnorthrefclk01_in;
    assign gtnorthrefclk10_int   = gtnorthrefclk10_in;
    assign gtnorthrefclk11_int   = gtnorthrefclk11_in;
    assign gtrefclk00_int        = gtrefclk00_in;
    assign gtrefclk01_int        = gtrefclk01_in;
    assign gtrefclk10_int        = gtrefclk10_in;
    assign gtrefclk11_int        = gtrefclk11_in;
    assign gtsouthrefclk00_int   = gtsouthrefclk00_in;
    assign gtsouthrefclk01_int   = gtsouthrefclk01_in;
    assign gtsouthrefclk10_int   = gtsouthrefclk10_in;
    assign gtsouthrefclk11_int   = gtsouthrefclk11_in;
    assign pmarsvd0_int          = pmarsvd0_in;
    assign pmarsvd1_int          = pmarsvd1_in;
    assign qpll0clkrsvd0_int     = qpll0clkrsvd0_in;
    assign qpll0clkrsvd1_int     = qpll0clkrsvd1_in;
    assign qpll0lockdetclk_int   = qpll0lockdetclk_in;
    assign qpll0locken_int       = qpll0locken_in;
    assign qpll0pd_int           = qpll0pd_in;
    assign qpll0refclksel_int    = qpll0refclksel_in;
  //assign qpll0reset_int        = qpll0reset_in;
    assign qpll1clkrsvd0_int     = qpll1clkrsvd0_in;
    assign qpll1clkrsvd1_int     = qpll1clkrsvd1_in;
    assign qpll1lockdetclk_int   = qpll1lockdetclk_in;
    assign qpll1locken_int       = qpll1locken_in;
    assign qpll1pd_int           = qpll1pd_in;
    assign qpll1refclksel_int    = qpll1refclksel_in;
  //assign qpll1reset_int        = qpll1reset_in;
    assign qpllrsvd1_int         = qpllrsvd1_in;
    assign qpllrsvd2_int         = qpllrsvd2_in;
    assign qpllrsvd3_int         = qpllrsvd3_in;
    assign qpllrsvd4_int         = qpllrsvd4_in;
    assign rcalenb_int           = rcalenb_in;
    assign drpdo_common_out      = drpdo_common_int;
    assign drprdy_common_out     = drprdy_common_int;
    assign pmarsvdout0_out       = pmarsvdout0_int;
    assign pmarsvdout1_out       = pmarsvdout1_int;
    assign qpll0fbclklost_out    = qpll0fbclklost_int;
    assign qpll0lock_out         = qpll0lock_int;
    assign qpll0outclk_out       = qpll0outclk_int;
    assign qpll0outrefclk_out    = qpll0outrefclk_int;
    assign qpll0refclklost_out   = qpll0refclklost_int;
    assign qpll1fbclklost_out    = qpll1fbclklost_int;
    assign qpll1lock_out         = qpll1lock_int;
    assign qpll1outclk_out       = qpll1outclk_int;
    assign qpll1outrefclk_out    = qpll1outrefclk_int;
    assign qpll1refclklost_out   = qpll1refclklost_int;
    assign qplldmonitor0_out     = qplldmonitor0_int;
    assign qplldmonitor1_out     = qplldmonitor1_int;
    assign refclkoutmonitor0_out = refclkoutmonitor0_int;
    assign refclkoutmonitor1_out = refclkoutmonitor1_int;
    assign rxrecclk0_sel_out     = rxrecclk0_sel_int;
    assign rxrecclk1_sel_out     = rxrecclk1_sel_int;

    // If transceiver common blocks are to be used within the core boundary, then for each transceiver quad which
    // contains one or more transceiver channel resources, generate an instance of the primitive wrapper containing
    // one parameterized common primitive
    if (`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CM > 0) begin : gen_common
      genvar cm;
      for (cm = 0; cm < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_COMMONS; cm = cm + 1) begin : gen_common_container
        if (P_COMMON_ENABLE[cm] == 1'b1) begin : gen_enabled_common

          GigEthGthUltraScaleCore_gt_gthe3_common_wrapper gthe3_common_wrapper_inst (
            .GTHE3_COMMON_BGBYPASSB         (bgbypassb_int         [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_BGMONITORENB      (bgmonitorenb_int      [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_BGPDB             (bgpdb_int             [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_BGRCALOVRD        (bgrcalovrd_int        [f_ub_cm( 5,(4*cm)+3) : f_lb_cm( 5,4*cm)]),
            .GTHE3_COMMON_BGRCALOVRDENB     (bgrcalovrdenb_int     [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_DRPADDR           (drpaddr_common_int    [f_ub_cm( 9,(4*cm)+3) : f_lb_cm( 9,4*cm)]),
            .GTHE3_COMMON_DRPCLK            (drpclk_common_int     [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_DRPDI             (drpdi_common_int      [f_ub_cm(16,(4*cm)+3) : f_lb_cm(16,4*cm)]),
            .GTHE3_COMMON_DRPEN             (drpen_common_int      [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_DRPWE             (drpwe_common_int      [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTGREFCLK0        (gtgrefclk0_int        [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTGREFCLK1        (gtgrefclk1_int        [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTNORTHREFCLK00   (gtnorthrefclk00_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTNORTHREFCLK01   (gtnorthrefclk01_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTNORTHREFCLK10   (gtnorthrefclk10_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTNORTHREFCLK11   (gtnorthrefclk11_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTREFCLK00        (gtrefclk00_int        [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTREFCLK01        (gtrefclk01_int        [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTREFCLK10        (gtrefclk10_int        [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTREFCLK11        (gtrefclk11_int        [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTSOUTHREFCLK00   (gtsouthrefclk00_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTSOUTHREFCLK01   (gtsouthrefclk01_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTSOUTHREFCLK10   (gtsouthrefclk10_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_GTSOUTHREFCLK11   (gtsouthrefclk11_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_PMARSVD0          (pmarsvd0_int          [f_ub_cm( 8,(4*cm)+3) : f_lb_cm( 8,4*cm)]),
            .GTHE3_COMMON_PMARSVD1          (pmarsvd1_int          [f_ub_cm( 8,(4*cm)+3) : f_lb_cm( 8,4*cm)]),
            .GTHE3_COMMON_QPLL0CLKRSVD0     (qpll0clkrsvd0_int     [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL0CLKRSVD1     (qpll0clkrsvd1_int     [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL0LOCKDETCLK   (qpll0lockdetclk_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL0LOCKEN       (qpll0locken_int       [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL0PD           (qpll0pd_int           [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL0REFCLKSEL    (qpll0refclksel_int    [f_ub_cm( 3,(4*cm)+3) : f_lb_cm( 3,4*cm)]),
            .GTHE3_COMMON_QPLL0RESET        (qpll0reset_int        [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1CLKRSVD0     (qpll1clkrsvd0_int     [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1CLKRSVD1     (qpll1clkrsvd1_int     [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1LOCKDETCLK   (qpll1lockdetclk_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1LOCKEN       (qpll1locken_int       [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1PD           (qpll1pd_int           [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1REFCLKSEL    (qpll1refclksel_int    [f_ub_cm( 3,(4*cm)+3) : f_lb_cm( 3,4*cm)]),
            .GTHE3_COMMON_QPLL1RESET        (qpll1reset_int        [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLLRSVD1         (qpllrsvd1_int         [f_ub_cm( 8,(4*cm)+3) : f_lb_cm( 8,4*cm)]),
            .GTHE3_COMMON_QPLLRSVD2         (qpllrsvd2_int         [f_ub_cm( 5,(4*cm)+3) : f_lb_cm( 5,4*cm)]),
            .GTHE3_COMMON_QPLLRSVD3         (qpllrsvd3_int         [f_ub_cm( 5,(4*cm)+3) : f_lb_cm( 5,4*cm)]),
            .GTHE3_COMMON_QPLLRSVD4         (qpllrsvd4_int         [f_ub_cm( 8,(4*cm)+3) : f_lb_cm( 8,4*cm)]),
            .GTHE3_COMMON_RCALENB           (rcalenb_int           [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_DRPDO             (drpdo_common_int      [f_ub_cm(16,(4*cm)+3) : f_lb_cm(16,4*cm)]),
            .GTHE3_COMMON_DRPRDY            (drprdy_common_int     [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_PMARSVDOUT0       (pmarsvdout0_int       [f_ub_cm( 8,(4*cm)+3) : f_lb_cm( 8,4*cm)]),
            .GTHE3_COMMON_PMARSVDOUT1       (pmarsvdout1_int       [f_ub_cm( 8,(4*cm)+3) : f_lb_cm( 8,4*cm)]),
            .GTHE3_COMMON_QPLL0FBCLKLOST    (qpll0fbclklost_int    [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL0LOCK         (qpll0lock_int         [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL0OUTCLK       (qpll0outclk_int       [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL0OUTREFCLK    (qpll0outrefclk_int    [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL0REFCLKLOST   (qpll0refclklost_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1FBCLKLOST    (qpll1fbclklost_int    [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1LOCK         (qpll1lock_int         [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1OUTCLK       (qpll1outclk_int       [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1OUTREFCLK    (qpll1outrefclk_int    [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLL1REFCLKLOST   (qpll1refclklost_int   [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_QPLLDMONITOR0     (qplldmonitor0_int     [f_ub_cm( 8,(4*cm)+3) : f_lb_cm( 8,4*cm)]),
            .GTHE3_COMMON_QPLLDMONITOR1     (qplldmonitor1_int     [f_ub_cm( 8,(4*cm)+3) : f_lb_cm( 8,4*cm)]),
            .GTHE3_COMMON_REFCLKOUTMONITOR0 (refclkoutmonitor0_int [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_REFCLKOUTMONITOR1 (refclkoutmonitor1_int [f_ub_cm( 1,(4*cm)+3) : f_lb_cm( 1,4*cm)]),
            .GTHE3_COMMON_RXRECCLK0_SEL     (rxrecclk0_sel_int     [f_ub_cm( 2,(4*cm)+3) : f_lb_cm( 2,4*cm)]),
            .GTHE3_COMMON_RXRECCLK1_SEL     (rxrecclk1_sel_int     [f_ub_cm( 2,(4*cm)+3) : f_lb_cm( 2,4*cm)])
          );

        end
      end

    end
    else begin : gen_no_common

      assign drpdo_common_int      = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{16'b0}};
      assign drprdy_common_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign pmarsvdout0_int       = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 8'b0}};
      assign pmarsvdout1_int       = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 8'b0}};
      assign qpll0fbclklost_int    = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign qpll0lock_int         = gtwiz_reset_qpll0lock_in;
      assign qpll0outclk_int       = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign qpll0outrefclk_int    = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign qpll0refclklost_int   = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign qpll1fbclklost_int    = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign qpll1lock_int         = gtwiz_reset_qpll1lock_in;
      assign qpll1outclk_int       = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign qpll1outrefclk_int    = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign qpll1refclklost_int   = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign qplldmonitor0_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 8'b0}};
      assign qplldmonitor1_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 8'b0}};
      assign refclkoutmonitor0_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign refclkoutmonitor1_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 1'b0}};
      assign rxrecclk0_sel_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 2'b0}};
      assign rxrecclk1_sel_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{ 2'b0}};

    end


    // ----------------------------------------------------------------------------------------------------------------
    // Transceiver channel block declarations, assignments, and primitive wrapper conditional generation
    // ----------------------------------------------------------------------------------------------------------------

    // Declare the signal vectors used to map to transceiver channel-related ports
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cfgreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] clkrsvd0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] clkrsvd1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cplllockdetclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cplllocken_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllpd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllpd_ch_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] cpllrefclksel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllreset_ch_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] dmonfiforeset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] dmonitorclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  9)-1:0] drpaddr_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  9)-1:0] drpaddr_ch_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drpclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] drpdi_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] drpdi_ch_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drpen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drpen_ch_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drpwe_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drpwe_ch_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphicaldone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphicalstart_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphidrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphidwren_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphixrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] evoddphixwren_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] eyescanmode_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] eyescanreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] eyescantrigger_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtgrefclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gthrxn_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gthrxp_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtnorthrefclk0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtnorthrefclk1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtrefclk0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtrefclk1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtresetsel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] gtrsvd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtrxreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtsouthrefclk0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtsouthrefclk1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gttxreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] loopback_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] lpbkrxtxseren_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] lpbktxrxseren_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieeqrxeqadaptdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcierstidle_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pciersttxsyncstart_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieuserratedone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] pcsrsvdin_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] pcsrsvdin2_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] pmarsvdin_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] qpll0clk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] qpll0refclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] qpll1clk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] qpll1refclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] resetovrd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rstclkentx_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rx8b10ben_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxbufreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrfreqreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrhold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrresetrsv_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchbonden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] rxchbondi_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxchbondlevel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchbondmaster_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchbondslave_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcommadeten_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxdfeagcctrl_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfeagchold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfeagcovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfelfhold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfelfovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfelpmreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap10hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap10ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap11hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap11ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap12hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap12ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap13hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap13ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap14hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap14ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap15hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap15ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap2hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap2ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap3hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap3ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap4hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap4ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap5hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap5ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap6hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap6ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap7hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap7ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap8hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap8ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap9hold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfetap9ovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfeuthold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfeutovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfevphold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfevpovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfevsen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdfexyden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlybypass_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlyen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlyovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlysreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxelecidlemode_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxgearboxslip_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlatclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmgchold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmgcovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmhfhold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmhfovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmlfhold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmlfklovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmoshold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxlpmosovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxmcommaalignen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxmonitorsel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoobreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoscalreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoshold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  4)-1:0] rxosintcfg_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosinten_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosinthold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintstrobe_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosinttestovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxoutclksel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpcommaalignen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpcsreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxpd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphalign_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphalignen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphdlypd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphdlyreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxpllclksel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpmareset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpolarity_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprbscntreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  4)-1:0] rxprbssel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprogdivreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxqpien_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxrate_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxratemode_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslide_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslipoutclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslippma_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncallin_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncin_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncmode_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxsysclksel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxuserrdy_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxusrclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxusrclk2_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] sigvalidclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 20)-1:0] tstin_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] tx8b10bbypass_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] tx8b10ben_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txbufdiffctrl_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txcominit_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txcomsas_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txcomwake_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] txctrl0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] txctrl1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] txctrl2_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*128)-1:0] txdata_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] txdataextendrsvd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdeemph_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdetectrx_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  4)-1:0] txdiffctrl_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdiffpd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlybypass_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlyen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlyhold_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlyovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlysreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlyupdown_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txelecidle_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  6)-1:0] txheader_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txinhibit_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txlatclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  7)-1:0] txmaincursor_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txmargin_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txoutclksel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txoutclksel_ch_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpcsreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] txpd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpdelecidlemode_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphalign_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphalignen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphdlypd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphdlyreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphdlytstclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphinit_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpippmen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpippmovrden_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpippmpd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpippmsel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] txpippmstepsize_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpisopd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] txpllclksel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpmareset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpolarity_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] txpostcursor_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpostcursorinv_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txprbsforceerr_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  4)-1:0] txprbssel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] txprecursor_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txprecursorinv_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txprogdivreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txprogdivreset_ch_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpibiasen_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpistrongpdown_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpiweakpup_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txrate_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txratemode_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  7)-1:0] txsequence_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txswing_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncallin_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncin_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncmode_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] txsysclksel_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txuserrdy_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txusrclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txusrclk2_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] bufgtce_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] bufgtcemask_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  9)-1:0] bufgtdiv_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] bufgtreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] bufgtrstmask_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllfbclklost_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cplllock_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cplllock_ch_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpllrefclklost_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 17)-1:0] dmonitorout_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] drpdo_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] drprdy_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] eyescandataerror_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gthtxn_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gthtxp_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtpowergood_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] gtrefclkmonitor_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcierategen3_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcierateidle_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] pcierateqpllpd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] pcierateqpllreset_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pciesynctxsyncdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieusergen3rdy_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieuserphystatusrst_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] pcieuserratestart_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 12)-1:0] pcsrsvdout_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] phystatus_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] pinrsrvdas_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] resetexception_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxbufstatus_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxbyteisaligned_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxbyterealign_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrlock_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcdrphdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchanbondseq_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchanisaligned_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxchanrealign_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  5)-1:0] rxchbondo_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxclkcorcnt_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcominitdet_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcommadet_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcomsasdet_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxcomwakedet_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] rxctrl0_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] rxctrl1_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] rxctrl2_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] rxctrl3_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*128)-1:0] rxdata_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  8)-1:0] rxdataextendrsvd_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxdatavalid_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxdlysresetdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxelecidle_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  6)-1:0] rxheader_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxheadervalid_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  7)-1:0] rxmonitorout_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintstarted_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintstrobedone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxosintstrobestarted_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoutclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoutclkfabric_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxoutclkpcs_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphaligndone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxphalignerr_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxpmaresetdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprbserr_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprbslocked_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxprgdivresetdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxqpisenn_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxqpisenp_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxratedone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxrecclkout_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxresetdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsliderdy_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslipdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslipoutclkrdy_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxslippmardy_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] rxstartofseq_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] rxstatus_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxsyncout_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] rxvalid_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  2)-1:0] txbufstatus_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txcomfinish_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txdlysresetdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txoutclk_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txoutclkfabric_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txoutclkpcs_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphaligndone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txphinitdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txpmaresetdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txprgdivresetdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpisenn_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txqpisenp_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txratedone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txresetdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncdone_int;
    wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] txsyncout_int;

    // Assign transceiver channel-related inputs to the corresponding internal signal vectors
    // Note: commented assignments are replaced by assignments associated with helper blocks, later in this module
    assign cfgreset_int             = cfgreset_in;
    assign clkrsvd0_int             = clkrsvd0_in;
    assign clkrsvd1_int             = clkrsvd1_in;
    assign cplllockdetclk_int       = cplllockdetclk_in;
    assign cplllocken_int           = cplllocken_in;
  //assign cpllpd_int               = cpllpd_in;
    assign cpllrefclksel_int        = cpllrefclksel_in;
  //assign cpllreset_int            = cpllreset_in;
    assign dmonfiforeset_int        = dmonfiforeset_in;
    assign dmonitorclk_int          = dmonitorclk_in;
    assign drpaddr_int              = drpaddr_in;
    assign drpclk_int               = drpclk_in;
    assign drpdi_int                = drpdi_in;
    assign drpen_int                = drpen_in;
    assign drpwe_int                = drpwe_in;
    assign evoddphicaldone_int      = evoddphicaldone_in;
    assign evoddphicalstart_int     = evoddphicalstart_in;
    assign evoddphidrden_int        = evoddphidrden_in;
    assign evoddphidwren_int        = evoddphidwren_in;
    assign evoddphixrden_int        = evoddphixrden_in;
    assign evoddphixwren_int        = evoddphixwren_in;
    assign eyescanmode_int          = eyescanmode_in;
    assign eyescanreset_int         = eyescanreset_in;
    assign eyescantrigger_int       = eyescantrigger_in;
    assign gtgrefclk_int            = gtgrefclk_in;
    assign gthrxn_int               = gthrxn_in;
    assign gthrxp_int               = gthrxp_in;
    assign gtnorthrefclk0_int       = gtnorthrefclk0_in;
    assign gtnorthrefclk1_int       = gtnorthrefclk1_in;
    assign gtrefclk0_int            = gtrefclk0_in;
    assign gtrefclk1_int            = gtrefclk1_in;
    assign gtresetsel_int           = gtresetsel_in;
    assign gtrsvd_int               = gtrsvd_in;
  //assign gtrxreset_int            = gtrxreset_in;
    assign gtsouthrefclk0_int       = gtsouthrefclk0_in;
    assign gtsouthrefclk1_int       = gtsouthrefclk1_in;
  //assign gttxreset_int            = gttxreset_in;
    assign loopback_int             = loopback_in;
    assign lpbkrxtxseren_int        = lpbkrxtxseren_in;
    assign lpbktxrxseren_int        = lpbktxrxseren_in;
    assign pcieeqrxeqadaptdone_int  = pcieeqrxeqadaptdone_in;
    assign pcierstidle_int          = pcierstidle_in;
    assign pciersttxsyncstart_int   = pciersttxsyncstart_in;
    assign pcieuserratedone_int     = pcieuserratedone_in;
    assign pcsrsvdin_int            = pcsrsvdin_in;
    assign pcsrsvdin2_int           = pcsrsvdin2_in;
    assign pmarsvdin_int            = pmarsvdin_in;
  //assign qpll0clk_int             = qpll0clk_in;
  //assign qpll0refclk_int          = qpll0refclk_in;
  //assign qpll1clk_int             = qpll1clk_in;
  //assign qpll1refclk_int          = qpll1refclk_in;
    assign resetovrd_int            = resetovrd_in;
    assign rstclkentx_int           = rstclkentx_in;
    assign rx8b10ben_int            = rx8b10ben_in;
    assign rxbufreset_int           = rxbufreset_in;
    assign rxcdrfreqreset_int       = rxcdrfreqreset_in;
    assign rxcdrhold_int            = rxcdrhold_in;
    assign rxcdrovrden_int          = rxcdrovrden_in;
    assign rxcdrreset_int           = rxcdrreset_in;
    assign rxcdrresetrsv_int        = rxcdrresetrsv_in;
    assign rxchbonden_int           = rxchbonden_in;
    assign rxchbondi_int            = rxchbondi_in;
    assign rxchbondlevel_int        = rxchbondlevel_in;
    assign rxchbondmaster_int       = rxchbondmaster_in;
    assign rxchbondslave_int        = rxchbondslave_in;
    assign rxcommadeten_int         = rxcommadeten_in;
    assign rxdfeagcctrl_int         = rxdfeagcctrl_in;
    assign rxdfeagchold_int         = rxdfeagchold_in;
    assign rxdfeagcovrden_int       = rxdfeagcovrden_in;
    assign rxdfelfhold_int          = rxdfelfhold_in;
    assign rxdfelfovrden_int        = rxdfelfovrden_in;
    assign rxdfelpmreset_int        = rxdfelpmreset_in;
    assign rxdfetap10hold_int       = rxdfetap10hold_in;
    assign rxdfetap10ovrden_int     = rxdfetap10ovrden_in;
    assign rxdfetap11hold_int       = rxdfetap11hold_in;
    assign rxdfetap11ovrden_int     = rxdfetap11ovrden_in;
    assign rxdfetap12hold_int       = rxdfetap12hold_in;
    assign rxdfetap12ovrden_int     = rxdfetap12ovrden_in;
    assign rxdfetap13hold_int       = rxdfetap13hold_in;
    assign rxdfetap13ovrden_int     = rxdfetap13ovrden_in;
    assign rxdfetap14hold_int       = rxdfetap14hold_in;
    assign rxdfetap14ovrden_int     = rxdfetap14ovrden_in;
    assign rxdfetap15hold_int       = rxdfetap15hold_in;
    assign rxdfetap15ovrden_int     = rxdfetap15ovrden_in;
    assign rxdfetap2hold_int        = rxdfetap2hold_in;
    assign rxdfetap2ovrden_int      = rxdfetap2ovrden_in;
    assign rxdfetap3hold_int        = rxdfetap3hold_in;
    assign rxdfetap3ovrden_int      = rxdfetap3ovrden_in;
    assign rxdfetap4hold_int        = rxdfetap4hold_in;
    assign rxdfetap4ovrden_int      = rxdfetap4ovrden_in;
    assign rxdfetap5hold_int        = rxdfetap5hold_in;
    assign rxdfetap5ovrden_int      = rxdfetap5ovrden_in;
    assign rxdfetap6hold_int        = rxdfetap6hold_in;
    assign rxdfetap6ovrden_int      = rxdfetap6ovrden_in;
    assign rxdfetap7hold_int        = rxdfetap7hold_in;
    assign rxdfetap7ovrden_int      = rxdfetap7ovrden_in;
    assign rxdfetap8hold_int        = rxdfetap8hold_in;
    assign rxdfetap8ovrden_int      = rxdfetap8ovrden_in;
    assign rxdfetap9hold_int        = rxdfetap9hold_in;
    assign rxdfetap9ovrden_int      = rxdfetap9ovrden_in;
    assign rxdfeuthold_int          = rxdfeuthold_in;
    assign rxdfeutovrden_int        = rxdfeutovrden_in;
    assign rxdfevphold_int          = rxdfevphold_in;
    assign rxdfevpovrden_int        = rxdfevpovrden_in;
    assign rxdfevsen_int            = rxdfevsen_in;
    assign rxdfexyden_int           = rxdfexyden_in;
  //assign rxdlybypass_int          = rxdlybypass_in;
  //assign rxdlyen_int              = rxdlyen_in;
  //assign rxdlyovrden_int          = rxdlyovrden_in;
  //assign rxdlysreset_int          = rxdlysreset_in;
    assign rxelecidlemode_int       = rxelecidlemode_in;
    assign rxgearboxslip_int        = rxgearboxslip_in;
    assign rxlatclk_int             = rxlatclk_in;
    assign rxlpmen_int              = rxlpmen_in;
    assign rxlpmgchold_int          = rxlpmgchold_in;
    assign rxlpmgcovrden_int        = rxlpmgcovrden_in;
    assign rxlpmhfhold_int          = rxlpmhfhold_in;
    assign rxlpmhfovrden_int        = rxlpmhfovrden_in;
    assign rxlpmlfhold_int          = rxlpmlfhold_in;
    assign rxlpmlfklovrden_int      = rxlpmlfklovrden_in;
    assign rxlpmoshold_int          = rxlpmoshold_in;
    assign rxlpmosovrden_int        = rxlpmosovrden_in;
    assign rxmcommaalignen_int      = rxmcommaalignen_in;
    assign rxmonitorsel_int         = rxmonitorsel_in;
    assign rxoobreset_int           = rxoobreset_in;
    assign rxoscalreset_int         = rxoscalreset_in;
    assign rxoshold_int             = rxoshold_in;
    assign rxosintcfg_int           = rxosintcfg_in;
    assign rxosinten_int            = rxosinten_in;
    assign rxosinthold_int          = rxosinthold_in;
    assign rxosintovrden_int        = rxosintovrden_in;
    assign rxosintstrobe_int        = rxosintstrobe_in;
    assign rxosinttestovrden_int    = rxosinttestovrden_in;
    assign rxosovrden_int           = rxosovrden_in;
    assign rxoutclksel_int          = rxoutclksel_in;
    assign rxpcommaalignen_int      = rxpcommaalignen_in;
    assign rxpcsreset_int           = rxpcsreset_in;
    assign rxpd_int                 = rxpd_in;
  //assign rxphalign_int            = rxphalign_in;
  //assign rxphalignen_int          = rxphalignen_in;
  //assign rxphdlypd_int            = rxphdlypd_in;
  //assign rxphdlyreset_int         = rxphdlyreset_in;
  //assign rxphovrden_int           = rxphovrden_in;
    assign rxpllclksel_int          = rxpllclksel_in;
    assign rxpmareset_int           = rxpmareset_in;
    assign rxpolarity_int           = rxpolarity_in;
    assign rxprbscntreset_int       = rxprbscntreset_in;
    assign rxprbssel_int            = rxprbssel_in;
  //assign rxprogdivreset_int       = rxprogdivreset_in;
    assign rxqpien_int              = rxqpien_in;
    assign rxrate_int               = rxrate_in;
    assign rxratemode_int           = rxratemode_in;
    assign rxslide_int              = rxslide_in;
    assign rxslipoutclk_int         = rxslipoutclk_in;
    assign rxslippma_int            = rxslippma_in;
  //assign rxsyncallin_int          = rxsyncallin_in;
  //assign rxsyncin_int             = rxsyncin_in;
  //assign rxsyncmode_int           = rxsyncmode_in;
    assign rxsysclksel_int          = rxsysclksel_in;
  //assign rxuserrdy_int            = rxuserrdy_in;
  //assign rxusrclk_int             = rxusrclk_in;
  //assign rxusrclk2_int            = rxusrclk2_in;
    assign sigvalidclk_int          = sigvalidclk_in;
    assign tstin_int                = tstin_in;
    assign tx8b10bbypass_int        = tx8b10bbypass_in;
    assign tx8b10ben_int            = tx8b10ben_in;
    assign txbufdiffctrl_int        = txbufdiffctrl_in;
    assign txcominit_int            = txcominit_in;
    assign txcomsas_int             = txcomsas_in;
    assign txcomwake_int            = txcomwake_in;
  //assign txctrl0_int              = txctrl0_in;
  //assign txctrl1_int              = txctrl1_in;
    assign txctrl2_int              = txctrl2_in;
  //assign txdata_int               = txdata_in;
    assign txdataextendrsvd_int     = txdataextendrsvd_in;
    assign txdeemph_int             = txdeemph_in;
    assign txdetectrx_int           = txdetectrx_in;
    assign txdiffctrl_int           = txdiffctrl_in;
    assign txdiffpd_int             = txdiffpd_in;
  //assign txdlybypass_int          = txdlybypass_in;
  //assign txdlyen_int              = txdlyen_in;
  //assign txdlyhold_int            = txdlyhold_in;
  //assign txdlyovrden_int          = txdlyovrden_in;
  //assign txdlysreset_int          = txdlysreset_in;
  //assign txdlyupdown_int          = txdlyupdown_in;
    assign txelecidle_int           = txelecidle_in;
    assign txheader_int             = txheader_in;
    assign txinhibit_int            = txinhibit_in;
    assign txlatclk_int             = txlatclk_in;
    assign txmaincursor_int         = txmaincursor_in;
    assign txmargin_int             = txmargin_in;
    assign txoutclksel_int          = txoutclksel_in;
    assign txpcsreset_int           = txpcsreset_in;
    assign txpd_int                 = txpd_in;
    assign txpdelecidlemode_int     = txpdelecidlemode_in;
  //assign txphalign_int            = txphalign_in;
  //assign txphalignen_int          = txphalignen_in;
  //assign txphdlypd_int            = txphdlypd_in;
  //assign txphdlyreset_int         = txphdlyreset_in;
  //assign txphdlytstclk_int        = txphdlytstclk_in;
  //assign txphinit_int             = txphinit_in;
  //assign txphovrden_int           = txphovrden_in;
    assign txpippmen_int            = txpippmen_in;
    assign txpippmovrden_int        = txpippmovrden_in;
    assign txpippmpd_int            = txpippmpd_in;
    assign txpippmsel_int           = txpippmsel_in;
    assign txpippmstepsize_int      = txpippmstepsize_in;
    assign txpisopd_int             = txpisopd_in;
    assign txpllclksel_int          = txpllclksel_in;
    assign txpmareset_int           = txpmareset_in;
    assign txpolarity_int           = txpolarity_in;
    assign txpostcursor_int         = txpostcursor_in;
    assign txpostcursorinv_int      = txpostcursorinv_in;
    assign txprbsforceerr_int       = txprbsforceerr_in;
    assign txprbssel_int            = txprbssel_in;
    assign txprecursor_int          = txprecursor_in;
    assign txprecursorinv_int       = txprecursorinv_in;
  //assign txprogdivreset_int       = txprogdivreset_in;
    assign txqpibiasen_int          = txqpibiasen_in;
    assign txqpistrongpdown_int     = txqpistrongpdown_in;
    assign txqpiweakpup_int         = txqpiweakpup_in;
    assign txrate_int               = txrate_in;
    assign txratemode_int           = txratemode_in;
    assign txsequence_int           = txsequence_in;
    assign txswing_int              = txswing_in;
  //assign txsyncallin_int          = txsyncallin_in;
  //assign txsyncin_int             = txsyncin_in;
  //assign txsyncmode_int           = txsyncmode_in;
    assign txsysclksel_int          = txsysclksel_in;
  //assign txuserrdy_int            = txuserrdy_in;
  //assign txusrclk_int             = txusrclk_in;
  //assign txusrclk2_int            = txusrclk2_in;
    assign bufgtce_out              = bufgtce_int;
    assign bufgtcemask_out          = bufgtcemask_int;
    assign bufgtdiv_out             = bufgtdiv_int;
    assign bufgtreset_out           = bufgtreset_int;
    assign bufgtrstmask_out         = bufgtrstmask_int;
    assign cpllfbclklost_out        = cpllfbclklost_int;
    assign cplllock_out             = cplllock_int;
    assign cpllrefclklost_out       = cpllrefclklost_int;
    assign dmonitorout_out          = dmonitorout_int;
  //assign drpdo_out                = drpdo_int;
  //assign drprdy_out               = drprdy_int;
    assign eyescandataerror_out     = eyescandataerror_int;
    assign gthtxn_out               = gthtxn_int;
    assign gthtxp_out               = gthtxp_int;
    assign gtpowergood_out          = gtpowergood_int;
    assign gtrefclkmonitor_out      = gtrefclkmonitor_int;
    assign pcierategen3_out         = pcierategen3_int;
    assign pcierateidle_out         = pcierateidle_int;
    assign pcierateqpllpd_out       = pcierateqpllpd_int;
    assign pcierateqpllreset_out    = pcierateqpllreset_int;
    assign pciesynctxsyncdone_out   = pciesynctxsyncdone_int;
    assign pcieusergen3rdy_out      = pcieusergen3rdy_int;
    assign pcieuserphystatusrst_out = pcieuserphystatusrst_int;
    assign pcieuserratestart_out    = pcieuserratestart_int;
    assign pcsrsvdout_out           = pcsrsvdout_int;
    assign phystatus_out            = phystatus_int;
    assign pinrsrvdas_out           = pinrsrvdas_int;
    assign resetexception_out       = resetexception_int;
    assign rxbufstatus_out          = rxbufstatus_int;
    assign rxbyteisaligned_out      = rxbyteisaligned_int;
    assign rxbyterealign_out        = rxbyterealign_int;
    assign rxcdrlock_out            = rxcdrlock_int;
    assign rxcdrphdone_out          = rxcdrphdone_int;
    assign rxchanbondseq_out        = rxchanbondseq_int;
    assign rxchanisaligned_out      = rxchanisaligned_int;
    assign rxchanrealign_out        = rxchanrealign_int;
    assign rxchbondo_out            = rxchbondo_int;
    assign rxclkcorcnt_out          = rxclkcorcnt_int;
    assign rxcominitdet_out         = rxcominitdet_int;
    assign rxcommadet_out           = rxcommadet_int;
    assign rxcomsasdet_out          = rxcomsasdet_int;
    assign rxcomwakedet_out         = rxcomwakedet_int;
    assign rxctrl0_out              = rxctrl0_int;
    assign rxctrl1_out              = rxctrl1_int;
    assign rxctrl2_out              = rxctrl2_int;
    assign rxctrl3_out              = rxctrl3_int;
    assign rxdata_out               = rxdata_int;
    assign rxdataextendrsvd_out     = rxdataextendrsvd_int;
    assign rxdatavalid_out          = rxdatavalid_int;
    assign rxdlysresetdone_out      = rxdlysresetdone_int;
    assign rxelecidle_out           = rxelecidle_int;
    assign rxheader_out             = rxheader_int;
    assign rxheadervalid_out        = rxheadervalid_int;
    assign rxmonitorout_out         = rxmonitorout_int;
    assign rxosintdone_out          = rxosintdone_int;
    assign rxosintstarted_out       = rxosintstarted_int;
    assign rxosintstrobedone_out    = rxosintstrobedone_int;
    assign rxosintstrobestarted_out = rxosintstrobestarted_int;
    assign rxoutclk_out             = rxoutclk_int;
    assign rxoutclkfabric_out       = rxoutclkfabric_int;
    assign rxoutclkpcs_out          = rxoutclkpcs_int;
    assign rxphaligndone_out        = rxphaligndone_int;
    assign rxphalignerr_out         = rxphalignerr_int;
    assign rxpmaresetdone_out       = rxpmaresetdone_int;
    assign rxprbserr_out            = rxprbserr_int;
    assign rxprbslocked_out         = rxprbslocked_int;
    assign rxprgdivresetdone_out    = rxprgdivresetdone_int;
    assign rxqpisenn_out            = rxqpisenn_int;
    assign rxqpisenp_out            = rxqpisenp_int;
    assign rxratedone_out           = rxratedone_int;
    assign rxrecclkout_out          = rxrecclkout_int;
    assign rxresetdone_out          = rxresetdone_int;
    assign rxsliderdy_out           = rxsliderdy_int;
    assign rxslipdone_out           = rxslipdone_int;
    assign rxslipoutclkrdy_out      = rxslipoutclkrdy_int;
    assign rxslippmardy_out         = rxslippmardy_int;
    assign rxstartofseq_out         = rxstartofseq_int;
    assign rxstatus_out             = rxstatus_int;
    assign rxsyncdone_out           = rxsyncdone_int;
    assign rxsyncout_out            = rxsyncout_int;
    assign rxvalid_out              = rxvalid_int;
    assign txbufstatus_out          = txbufstatus_int;
    assign txcomfinish_out          = txcomfinish_int;
    assign txdlysresetdone_out      = txdlysresetdone_int;
    assign txoutclk_out             = txoutclk_int;
    assign txoutclkfabric_out       = txoutclkfabric_int;
    assign txoutclkpcs_out          = txoutclkpcs_int;
    assign txphaligndone_out        = txphaligndone_int;
    assign txphinitdone_out         = txphinitdone_int;
    assign txpmaresetdone_out       = txpmaresetdone_int;
  //assign txprgdivresetdone_out    = txprgdivresetdone_int;
    assign txqpisenn_out            = txqpisenn_int;
    assign txqpisenp_out            = txqpisenp_int;
    assign txratedone_out           = txratedone_int;
    assign txresetdone_out          = txresetdone_int;
    assign txsyncdone_out           = txsyncdone_int;
    assign txsyncout_out            = txsyncout_int;

    // For each transceiver quad which contains one or more transceiver channel resources, generate an instance of
    // the primitive wrapper containing that number of parameterized channel primitives
    genvar ch;
    for (ch = 0; ch < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_MAX_NUM_COMMONS; ch = ch + 1) begin : gen_channel_container
      if (f_num_ch_in_quad(4*ch) > 0) begin : gen_enabled_channel

        GigEthGthUltraScaleCore_gt_gthe3_channel_wrapper #(
          .NUM_CHANNELS (f_num_ch_in_quad(4*ch))
        ) gthe3_channel_wrapper_inst (
          .GTHE3_CHANNEL_CFGRESET             (cfgreset_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_CLKRSVD0             (clkrsvd0_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_CLKRSVD1             (clkrsvd1_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_CPLLLOCKDETCLK       (cplllockdetclk_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_CPLLLOCKEN           (cplllocken_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_CPLLPD               (cpllpd_ch_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_CPLLREFCLKSEL        (cpllrefclksel_int        [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_CPLLRESET            (cpllreset_ch_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_DMONFIFORESET        (dmonfiforeset_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_DMONITORCLK          (dmonitorclk_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_DRPADDR              (drpaddr_ch_int           [f_ub_ch(  9,(4*ch)+3) : f_lb_ch(  9,4*ch)]),
          .GTHE3_CHANNEL_DRPCLK               (drpclk_int               [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_DRPDI                (drpdi_ch_int             [f_ub_ch( 16,(4*ch)+3) : f_lb_ch( 16,4*ch)]),
          .GTHE3_CHANNEL_DRPEN                (drpen_ch_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_DRPWE                (drpwe_ch_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EVODDPHICALDONE      (evoddphicaldone_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EVODDPHICALSTART     (evoddphicalstart_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EVODDPHIDRDEN        (evoddphidrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EVODDPHIDWREN        (evoddphidwren_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EVODDPHIXRDEN        (evoddphixrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EVODDPHIXWREN        (evoddphixwren_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EYESCANMODE          (eyescanmode_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EYESCANRESET         (eyescanreset_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EYESCANTRIGGER       (eyescantrigger_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTGREFCLK            (gtgrefclk_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTHRXN               (gthrxn_int               [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTHRXP               (gthrxp_int               [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTNORTHREFCLK0       (gtnorthrefclk0_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTNORTHREFCLK1       (gtnorthrefclk1_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTREFCLK0            (gtrefclk0_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTREFCLK1            (gtrefclk1_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTRESETSEL           (gtresetsel_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTRSVD               (gtrsvd_int               [f_ub_ch( 16,(4*ch)+3) : f_lb_ch( 16,4*ch)]),
          .GTHE3_CHANNEL_GTRXRESET            (gtrxreset_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTSOUTHREFCLK0       (gtsouthrefclk0_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTSOUTHREFCLK1       (gtsouthrefclk1_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTTXRESET            (gttxreset_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_LOOPBACK             (loopback_int             [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_LPBKRXTXSEREN        (lpbkrxtxseren_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_LPBKTXRXSEREN        (lpbktxrxseren_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIEEQRXEQADAPTDONE  (pcieeqrxeqadaptdone_int  [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIERSTIDLE          (pcierstidle_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIERSTTXSYNCSTART   (pciersttxsyncstart_int   [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIEUSERRATEDONE     (pcieuserratedone_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCSRSVDIN            (pcsrsvdin_int            [f_ub_ch( 16,(4*ch)+3) : f_lb_ch( 16,4*ch)]),
          .GTHE3_CHANNEL_PCSRSVDIN2           (pcsrsvdin2_int           [f_ub_ch(  5,(4*ch)+3) : f_lb_ch(  5,4*ch)]),
          .GTHE3_CHANNEL_PMARSVDIN            (pmarsvdin_int            [f_ub_ch(  5,(4*ch)+3) : f_lb_ch(  5,4*ch)]),
          .GTHE3_CHANNEL_QPLL0CLK             (qpll0clk_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_QPLL0REFCLK          (qpll0refclk_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_QPLL1CLK             (qpll1clk_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_QPLL1REFCLK          (qpll1refclk_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RESETOVRD            (resetovrd_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RSTCLKENTX           (rstclkentx_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RX8B10BEN            (rx8b10ben_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXBUFRESET           (rxbufreset_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCDRFREQRESET       (rxcdrfreqreset_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCDRHOLD            (rxcdrhold_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCDROVRDEN          (rxcdrovrden_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCDRRESET           (rxcdrreset_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCDRRESETRSV        (rxcdrresetrsv_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCHBONDEN           (rxchbonden_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCHBONDI            (rxchbondi_int            [f_ub_ch(  5,(4*ch)+3) : f_lb_ch(  5,4*ch)]),
          .GTHE3_CHANNEL_RXCHBONDLEVEL        (rxchbondlevel_int        [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_RXCHBONDMASTER       (rxchbondmaster_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCHBONDSLAVE        (rxchbondslave_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCOMMADETEN         (rxcommadeten_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFEAGCCTRL         (rxdfeagcctrl_int         [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXDFEAGCHOLD         (rxdfeagchold_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFEAGCOVRDEN       (rxdfeagcovrden_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFELFHOLD          (rxdfelfhold_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFELFOVRDEN        (rxdfelfovrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFELPMRESET        (rxdfelpmreset_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP10HOLD       (rxdfetap10hold_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP10OVRDEN     (rxdfetap10ovrden_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP11HOLD       (rxdfetap11hold_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP11OVRDEN     (rxdfetap11ovrden_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP12HOLD       (rxdfetap12hold_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP12OVRDEN     (rxdfetap12ovrden_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP13HOLD       (rxdfetap13hold_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP13OVRDEN     (rxdfetap13ovrden_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP14HOLD       (rxdfetap14hold_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP14OVRDEN     (rxdfetap14ovrden_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP15HOLD       (rxdfetap15hold_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP15OVRDEN     (rxdfetap15ovrden_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP2HOLD        (rxdfetap2hold_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP2OVRDEN      (rxdfetap2ovrden_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP3HOLD        (rxdfetap3hold_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP3OVRDEN      (rxdfetap3ovrden_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP4HOLD        (rxdfetap4hold_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP4OVRDEN      (rxdfetap4ovrden_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP5HOLD        (rxdfetap5hold_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP5OVRDEN      (rxdfetap5ovrden_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP6HOLD        (rxdfetap6hold_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP6OVRDEN      (rxdfetap6ovrden_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP7HOLD        (rxdfetap7hold_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP7OVRDEN      (rxdfetap7ovrden_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP8HOLD        (rxdfetap8hold_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP8OVRDEN      (rxdfetap8ovrden_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP9HOLD        (rxdfetap9hold_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFETAP9OVRDEN      (rxdfetap9ovrden_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFEUTHOLD          (rxdfeuthold_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFEUTOVRDEN        (rxdfeutovrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFEVPHOLD          (rxdfevphold_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFEVPOVRDEN        (rxdfevpovrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFEVSEN            (rxdfevsen_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDFEXYDEN           (rxdfexyden_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDLYBYPASS          (rxdlybypass_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDLYEN              (rxdlyen_int              [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDLYOVRDEN          (rxdlyovrden_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXDLYSRESET          (rxdlysreset_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXELECIDLEMODE       (rxelecidlemode_int       [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXGEARBOXSLIP        (rxgearboxslip_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLATCLK             (rxlatclk_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLPMEN              (rxlpmen_int              [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLPMGCHOLD          (rxlpmgchold_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLPMGCOVRDEN        (rxlpmgcovrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLPMHFHOLD          (rxlpmhfhold_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLPMHFOVRDEN        (rxlpmhfovrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLPMLFHOLD          (rxlpmlfhold_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLPMLFKLOVRDEN      (rxlpmlfklovrden_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLPMOSHOLD          (rxlpmoshold_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXLPMOSOVRDEN        (rxlpmosovrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXMCOMMAALIGNEN      (rxmcommaalignen_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXMONITORSEL         (rxmonitorsel_int         [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXOOBRESET           (rxoobreset_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSCALRESET         (rxoscalreset_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSHOLD             (rxoshold_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTCFG           (rxosintcfg_int           [f_ub_ch(  4,(4*ch)+3) : f_lb_ch(  4,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTEN            (rxosinten_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTHOLD          (rxosinthold_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTOVRDEN        (rxosintovrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTSTROBE        (rxosintstrobe_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTTESTOVRDEN    (rxosinttestovrden_int    [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSOVRDEN           (rxosovrden_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOUTCLKSEL          (rxoutclksel_int          [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_RXPCOMMAALIGNEN      (rxpcommaalignen_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPCSRESET           (rxpcsreset_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPD                 (rxpd_int                 [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXPHALIGN            (rxphalign_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPHALIGNEN          (rxphalignen_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPHDLYPD            (rxphdlypd_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPHDLYRESET         (rxphdlyreset_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPHOVRDEN           (rxphovrden_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPLLCLKSEL          (rxpllclksel_int          [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXPMARESET           (rxpmareset_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPOLARITY           (rxpolarity_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPRBSCNTRESET       (rxprbscntreset_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPRBSSEL            (rxprbssel_int            [f_ub_ch(  4,(4*ch)+3) : f_lb_ch(  4,4*ch)]),
          .GTHE3_CHANNEL_RXPROGDIVRESET       (rxprogdivreset_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXQPIEN              (rxqpien_int              [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXRATE               (rxrate_int               [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_RXRATEMODE           (rxratemode_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSLIDE              (rxslide_int              [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSLIPOUTCLK         (rxslipoutclk_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSLIPPMA            (rxslippma_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSYNCALLIN          (rxsyncallin_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSYNCIN             (rxsyncin_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSYNCMODE           (rxsyncmode_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSYSCLKSEL          (rxsysclksel_int          [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXUSERRDY            (rxuserrdy_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXUSRCLK             (rxusrclk_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXUSRCLK2            (rxusrclk2_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_SIGVALIDCLK          (sigvalidclk_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TSTIN                (tstin_int                [f_ub_ch( 20,(4*ch)+3) : f_lb_ch( 20,4*ch)]),
          .GTHE3_CHANNEL_TX8B10BBYPASS        (tx8b10bbypass_int        [f_ub_ch(  8,(4*ch)+3) : f_lb_ch(  8,4*ch)]),
          .GTHE3_CHANNEL_TX8B10BEN            (tx8b10ben_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXBUFDIFFCTRL        (txbufdiffctrl_int        [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_TXCOMINIT            (txcominit_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXCOMSAS             (txcomsas_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXCOMWAKE            (txcomwake_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXCTRL0              (txctrl0_int              [f_ub_ch( 16,(4*ch)+3) : f_lb_ch( 16,4*ch)]),
          .GTHE3_CHANNEL_TXCTRL1              (txctrl1_int              [f_ub_ch( 16,(4*ch)+3) : f_lb_ch( 16,4*ch)]),
          .GTHE3_CHANNEL_TXCTRL2              (txctrl2_int              [f_ub_ch(  8,(4*ch)+3) : f_lb_ch(  8,4*ch)]),
          .GTHE3_CHANNEL_TXDATA               (txdata_int               [f_ub_ch(128,(4*ch)+3) : f_lb_ch(128,4*ch)]),
          .GTHE3_CHANNEL_TXDATAEXTENDRSVD     (txdataextendrsvd_int     [f_ub_ch(  8,(4*ch)+3) : f_lb_ch(  8,4*ch)]),
          .GTHE3_CHANNEL_TXDEEMPH             (txdeemph_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXDETECTRX           (txdetectrx_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXDIFFCTRL           (txdiffctrl_int           [f_ub_ch(  4,(4*ch)+3) : f_lb_ch(  4,4*ch)]),
          .GTHE3_CHANNEL_TXDIFFPD             (txdiffpd_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXDLYBYPASS          (txdlybypass_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXDLYEN              (txdlyen_int              [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXDLYHOLD            (txdlyhold_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXDLYOVRDEN          (txdlyovrden_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXDLYSRESET          (txdlysreset_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXDLYUPDOWN          (txdlyupdown_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXELECIDLE           (txelecidle_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXHEADER             (txheader_int             [f_ub_ch(  6,(4*ch)+3) : f_lb_ch(  6,4*ch)]),
          .GTHE3_CHANNEL_TXINHIBIT            (txinhibit_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXLATCLK             (txlatclk_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXMAINCURSOR         (txmaincursor_int         [f_ub_ch(  7,(4*ch)+3) : f_lb_ch(  7,4*ch)]),
          .GTHE3_CHANNEL_TXMARGIN             (txmargin_int             [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_TXOUTCLKSEL          (txoutclksel_ch_int       [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_TXPCSRESET           (txpcsreset_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPD                 (txpd_int                 [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_TXPDELECIDLEMODE     (txpdelecidlemode_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPHALIGN            (txphalign_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPHALIGNEN          (txphalignen_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPHDLYPD            (txphdlypd_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPHDLYRESET         (txphdlyreset_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPHDLYTSTCLK        (txphdlytstclk_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPHINIT             (txphinit_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPHOVRDEN           (txphovrden_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPIPPMEN            (txpippmen_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPIPPMOVRDEN        (txpippmovrden_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPIPPMPD            (txpippmpd_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPIPPMSEL           (txpippmsel_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPIPPMSTEPSIZE      (txpippmstepsize_int      [f_ub_ch(  5,(4*ch)+3) : f_lb_ch(  5,4*ch)]),
          .GTHE3_CHANNEL_TXPISOPD             (txpisopd_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPLLCLKSEL          (txpllclksel_int          [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_TXPMARESET           (txpmareset_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPOLARITY           (txpolarity_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPOSTCURSOR         (txpostcursor_int         [f_ub_ch(  5,(4*ch)+3) : f_lb_ch(  5,4*ch)]),
          .GTHE3_CHANNEL_TXPOSTCURSORINV      (txpostcursorinv_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPRBSFORCEERR       (txprbsforceerr_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPRBSSEL            (txprbssel_int            [f_ub_ch(  4,(4*ch)+3) : f_lb_ch(  4,4*ch)]),
          .GTHE3_CHANNEL_TXPRECURSOR          (txprecursor_int          [f_ub_ch(  5,(4*ch)+3) : f_lb_ch(  5,4*ch)]),
          .GTHE3_CHANNEL_TXPRECURSORINV       (txprecursorinv_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPROGDIVRESET       (txprogdivreset_ch_int    [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXQPIBIASEN          (txqpibiasen_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXQPISTRONGPDOWN     (txqpistrongpdown_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXQPIWEAKPUP         (txqpiweakpup_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXRATE               (txrate_int               [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_TXRATEMODE           (txratemode_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXSEQUENCE           (txsequence_int           [f_ub_ch(  7,(4*ch)+3) : f_lb_ch(  7,4*ch)]),
          .GTHE3_CHANNEL_TXSWING              (txswing_int              [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXSYNCALLIN          (txsyncallin_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXSYNCIN             (txsyncin_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXSYNCMODE           (txsyncmode_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXSYSCLKSEL          (txsysclksel_int          [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_TXUSERRDY            (txuserrdy_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXUSRCLK             (txusrclk_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXUSRCLK2            (txusrclk2_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_BUFGTCE              (bufgtce_int              [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_BUFGTCEMASK          (bufgtcemask_int          [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_BUFGTDIV             (bufgtdiv_int             [f_ub_ch(  9,(4*ch)+3) : f_lb_ch(  9,4*ch)]),
          .GTHE3_CHANNEL_BUFGTRESET           (bufgtreset_int           [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_BUFGTRSTMASK         (bufgtrstmask_int         [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_CPLLFBCLKLOST        (cpllfbclklost_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_CPLLLOCK             (cplllock_ch_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_CPLLREFCLKLOST       (cpllrefclklost_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_DMONITOROUT          (dmonitorout_int          [f_ub_ch( 17,(4*ch)+3) : f_lb_ch( 17,4*ch)]),
          .GTHE3_CHANNEL_DRPDO                (drpdo_int                [f_ub_ch( 16,(4*ch)+3) : f_lb_ch( 16,4*ch)]),
          .GTHE3_CHANNEL_DRPRDY               (drprdy_int               [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_EYESCANDATAERROR     (eyescandataerror_int     [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTHTXN               (gthtxn_int               [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTHTXP               (gthtxp_int               [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTPOWERGOOD          (gtpowergood_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_GTREFCLKMONITOR      (gtrefclkmonitor_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIERATEGEN3         (pcierategen3_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIERATEIDLE         (pcierateidle_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIERATEQPLLPD       (pcierateqpllpd_int       [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_PCIERATEQPLLRESET    (pcierateqpllreset_int    [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_PCIESYNCTXSYNCDONE   (pciesynctxsyncdone_int   [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIEUSERGEN3RDY      (pcieusergen3rdy_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIEUSERPHYSTATUSRST (pcieuserphystatusrst_int [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCIEUSERRATESTART    (pcieuserratestart_int    [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PCSRSVDOUT           (pcsrsvdout_int           [f_ub_ch( 12,(4*ch)+3) : f_lb_ch( 12,4*ch)]),
          .GTHE3_CHANNEL_PHYSTATUS            (phystatus_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_PINRSRVDAS           (pinrsrvdas_int           [f_ub_ch(  8,(4*ch)+3) : f_lb_ch(  8,4*ch)]),
          .GTHE3_CHANNEL_RESETEXCEPTION       (resetexception_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXBUFSTATUS          (rxbufstatus_int          [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_RXBYTEISALIGNED      (rxbyteisaligned_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXBYTEREALIGN        (rxbyterealign_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCDRLOCK            (rxcdrlock_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCDRPHDONE          (rxcdrphdone_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCHANBONDSEQ        (rxchanbondseq_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCHANISALIGNED      (rxchanisaligned_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCHANREALIGN        (rxchanrealign_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCHBONDO            (rxchbondo_int            [f_ub_ch(  5,(4*ch)+3) : f_lb_ch(  5,4*ch)]),
          .GTHE3_CHANNEL_RXCLKCORCNT          (rxclkcorcnt_int          [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXCOMINITDET         (rxcominitdet_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCOMMADET           (rxcommadet_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCOMSASDET          (rxcomsasdet_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCOMWAKEDET         (rxcomwakedet_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXCTRL0              (rxctrl0_int              [f_ub_ch( 16,(4*ch)+3) : f_lb_ch( 16,4*ch)]),
          .GTHE3_CHANNEL_RXCTRL1              (rxctrl1_int              [f_ub_ch( 16,(4*ch)+3) : f_lb_ch( 16,4*ch)]),
          .GTHE3_CHANNEL_RXCTRL2              (rxctrl2_int              [f_ub_ch(  8,(4*ch)+3) : f_lb_ch(  8,4*ch)]),
          .GTHE3_CHANNEL_RXCTRL3              (rxctrl3_int              [f_ub_ch(  8,(4*ch)+3) : f_lb_ch(  8,4*ch)]),
          .GTHE3_CHANNEL_RXDATA               (rxdata_int               [f_ub_ch(128,(4*ch)+3) : f_lb_ch(128,4*ch)]),
          .GTHE3_CHANNEL_RXDATAEXTENDRSVD     (rxdataextendrsvd_int     [f_ub_ch(  8,(4*ch)+3) : f_lb_ch(  8,4*ch)]),
          .GTHE3_CHANNEL_RXDATAVALID          (rxdatavalid_int          [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXDLYSRESETDONE      (rxdlysresetdone_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXELECIDLE           (rxelecidle_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXHEADER             (rxheader_int             [f_ub_ch(  6,(4*ch)+3) : f_lb_ch(  6,4*ch)]),
          .GTHE3_CHANNEL_RXHEADERVALID        (rxheadervalid_int        [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXMONITOROUT         (rxmonitorout_int         [f_ub_ch(  7,(4*ch)+3) : f_lb_ch(  7,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTDONE          (rxosintdone_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTSTARTED       (rxosintstarted_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTSTROBEDONE    (rxosintstrobedone_int    [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOSINTSTROBESTARTED (rxosintstrobestarted_int [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOUTCLK             (rxoutclk_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOUTCLKFABRIC       (rxoutclkfabric_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXOUTCLKPCS          (rxoutclkpcs_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPHALIGNDONE        (rxphaligndone_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPHALIGNERR         (rxphalignerr_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPMARESETDONE       (rxpmaresetdone_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPRBSERR            (rxprbserr_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPRBSLOCKED         (rxprbslocked_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXPRGDIVRESETDONE    (rxprgdivresetdone_int    [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXQPISENN            (rxqpisenn_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXQPISENP            (rxqpisenp_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXRATEDONE           (rxratedone_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXRECCLKOUT          (rxrecclkout_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXRESETDONE          (rxresetdone_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSLIDERDY           (rxsliderdy_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSLIPDONE           (rxslipdone_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSLIPOUTCLKRDY      (rxslipoutclkrdy_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSLIPPMARDY         (rxslippmardy_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSTARTOFSEQ         (rxstartofseq_int         [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_RXSTATUS             (rxstatus_int             [f_ub_ch(  3,(4*ch)+3) : f_lb_ch(  3,4*ch)]),
          .GTHE3_CHANNEL_RXSYNCDONE           (rxsyncdone_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXSYNCOUT            (rxsyncout_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_RXVALID              (rxvalid_int              [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXBUFSTATUS          (txbufstatus_int          [f_ub_ch(  2,(4*ch)+3) : f_lb_ch(  2,4*ch)]),
          .GTHE3_CHANNEL_TXCOMFINISH          (txcomfinish_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXDLYSRESETDONE      (txdlysresetdone_int      [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXOUTCLK             (txoutclk_int             [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXOUTCLKFABRIC       (txoutclkfabric_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXOUTCLKPCS          (txoutclkpcs_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPHALIGNDONE        (txphaligndone_int        [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPHINITDONE         (txphinitdone_int         [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPMARESETDONE       (txpmaresetdone_int       [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXPRGDIVRESETDONE    (txprgdivresetdone_int    [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXQPISENN            (txqpisenn_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXQPISENP            (txqpisenp_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXRATEDONE           (txratedone_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXRESETDONE          (txresetdone_int          [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXSYNCDONE           (txsyncdone_int           [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)]),
          .GTHE3_CHANNEL_TXSYNCOUT            (txsyncout_int            [f_ub_ch(  1,(4*ch)+3) : f_lb_ch(  1,4*ch)])
        );

      end
    end


    // ----------------------------------------------------------------------------------------------------------------
    // Transceiver channel CPLL calibration block
    // ----------------------------------------------------------------------------------------------------------------

    // If the transceiver channel CPLL calibration block is required, instantiate it for each transceiver channel
    if ((C_INCLUDE_CPLL_CAL         == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_INCLUDE_CPLL_CAL__INCLUDE) ||
        (((C_INCLUDE_CPLL_CAL       == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_INCLUDE_CPLL_CAL__DEPENDENT) &&
         ((C_GT_REV                 == 11) ||
          (C_GT_REV                 == 12) ||
          (C_GT_REV                 == 14) ||
          (C_GT_REV                 == 16))) &&
         (((C_TX_ENABLE             == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_ENABLE__ENABLED) &&
           (C_TX_PLL_TYPE           == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL)) ||
          ((C_RX_ENABLE             == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_ENABLE__ENABLED) &&
           (C_RX_PLL_TYPE           == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL)) ||
          ((C_TXPROGDIV_FREQ_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TXPROGDIV_FREQ_ENABLE__ENABLED) &&
           (C_TXPROGDIV_FREQ_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TXPROGDIV_FREQ_SOURCE__CPLL))))) begin : gen_cpll_cal

      // Use local parameters and declare both debug and connectivity wires for use with the CPLL calibration block
      wire [15:0] p_cpll_cal_freq_count_window_int      = P_CPLL_CAL_FREQ_COUNT_WINDOW;
      wire [17:0] p_cpll_cal_txoutclk_period_int        = P_CPLL_CAL_TXOUTCLK_PERIOD;
      wire [15:0] p_cpll_cal_wait_deassert_cpllpd_int   = P_CPLL_CAL_WAIT_DEASSERT_CPLLPD;
      wire [17:0] p_cpll_cal_txoutclk_period_div100_int = P_CPLL_CAL_TXOUTCLK_PERIOD_DIV100;

      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] cpll_cal_fail_int;
      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] cpll_cal_done_int;
      wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] cpll_cal_debug_int;

      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] cpll_cal_reset_int;
      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] txprgdivresetdone_cpll_cal_int;
      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] cplllock_cpll_cal_int;
      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] drprdy_cpll_cal_int;
      wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] drpdo_cpll_cal_int;
      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] cpllreset_cpll_cal_int;
      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] cpllpd_cpll_cal_int;
      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] txprogdivreset_cpll_cal_int;
      wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  3)-1:0] txoutclksel_cpll_cal_int;
      wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  9)-1:0] drpaddr_cpll_cal_int;
      wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 16)-1:0] drpdi_cpll_cal_int;
      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] drpen_cpll_cal_int;
      wire [ `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH     -1:0] drpwe_cpll_cal_int;

      // The TXOUTCLK_PERIOD_IN and CNT_TOL_IN ports are normally driven by an internally-calculated value. When INCLUDE_CPLL_CAL is 1,
      // they are driven as inputs for PLL-switching and rate change special cases, and the BUFG_GT CE input is provided by the user.
      wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 18)-1:0] cpll_cal_txoutclk_period_int;
      wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH* 18)-1:0] cpll_cal_cnt_tol_int;
      wire [(`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH*  1)-1:0] cpll_cal_bufg_ce_int;
      if (C_INCLUDE_CPLL_CAL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_INCLUDE_CPLL_CAL__INCLUDE) begin : gen_txoutclk_pd_input
        assign cpll_cal_txoutclk_period_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_gthe3_cpll_cal_txoutclk_period_in}};
        assign cpll_cal_cnt_tol_int         = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_gthe3_cpll_cal_cnt_tol_in}};
        assign cpll_cal_bufg_ce_int         = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_gthe3_cpll_cal_bufg_ce_in}};
      end
      else begin : gen_txoutclk_pd_internal
        assign cpll_cal_txoutclk_period_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{p_cpll_cal_txoutclk_period_int}};
        assign cpll_cal_cnt_tol_int         = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{p_cpll_cal_txoutclk_period_div100_int}};
        assign cpll_cal_bufg_ce_int         = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{1'b1}};
      end

      // The CPLL calibration block for a given transceiver channel is reset when either the CPLL reset signal or the
      // CPLL power-down signal is asserted for that channel
      assign cpll_cal_reset_int = cpllreset_int | cpllpd_int;

      // Instantiate one CPLL calibration block for each transceiver channel
      genvar cal;
      for (cal = 0; cal < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH; cal = cal + 1) begin : gen_cpll_cal_inst
        gtwizard_ultrascale_v1_6_2_gthe3_cpll_cal gtwizard_ultrascale_v1_6_2_gthe3_cpll_cal_inst (
          .TXOUTCLK_PERIOD_IN         (cpll_cal_txoutclk_period_int[(18*cal)+17:18*cal]),
          .WAIT_DEASSERT_CPLLPD_IN    (p_cpll_cal_wait_deassert_cpllpd_int),
          .CNT_TOL_IN                 (cpll_cal_cnt_tol_int[(18*cal)+17:18*cal]),
          .FREQ_COUNT_WINDOW_IN       (p_cpll_cal_freq_count_window_int),
          .RESET_IN                   (cpll_cal_reset_int[cal]),
          .CLK_IN                     (drpclk_int[cal]),
          .USER_TXOUTCLK_BUFG_CE_IN   (cpll_cal_bufg_ce_int[cal]),
          .USER_TXOUTCLK_BUFG_CLR_IN  (gtwiz_userclk_tx_reset_in),
          .USER_TXPROGDIVRESET_IN     (txprogdivreset_int[cal]),
          .USER_TXPRGDIVRESETDONE_OUT (txprgdivresetdone_cpll_cal_int[cal]),
          .USER_TXOUTCLKSEL_IN        (txoutclksel_int[(3*cal)+2:3*cal]),
          .USER_CPLLLOCK_OUT          (cplllock_cpll_cal_int[cal]),
          .USER_CHANNEL_DRPADDR_IN    (drpaddr_int[(9*cal)+8:9*cal]),
          .USER_CHANNEL_DRPDI_IN      (drpdi_int[(16*cal)+15:16*cal]),
          .USER_CHANNEL_DRPEN_IN      (drpen_int[cal]),
          .USER_CHANNEL_DRPWE_IN      (drpwe_int[cal]),
          .USER_CHANNEL_DRPRDY_OUT    (drprdy_cpll_cal_int[cal]),
          .USER_CHANNEL_DRPDO_OUT     (drpdo_cpll_cal_int[(16*cal)+15:16*cal]),
          .CPLL_CAL_FAIL              (cpll_cal_fail_int[cal]),
          .CPLL_CAL_DONE              (cpll_cal_done_int[cal]),
          .DEBUG_OUT                  (cpll_cal_debug_int[(16*cal)+15:16*cal]),
          .GTHE3_TXOUTCLK_IN          (txoutclk_int[cal]),
          .GTHE3_CPLLLOCK_IN          (cplllock_ch_int[cal]),
          .GTHE3_CPLLRESET_OUT        (cpllreset_cpll_cal_int[cal]),
          .GTHE3_CPLLPD_OUT           (cpllpd_cpll_cal_int[cal]),
          .GTHE3_TXPROGDIVRESET_OUT   (txprogdivreset_cpll_cal_int[cal]),
          .GTHE3_TXOUTCLKSEL_OUT      (txoutclksel_cpll_cal_int[(3*cal)+2:3*cal]),
          .GTHE3_TXPRGDIVRESETDONE_IN (txprgdivresetdone_int[cal]),
          .GTHE3_CHANNEL_DRPADDR_OUT  (drpaddr_cpll_cal_int[(9*cal)+8:9*cal]),
          .GTHE3_CHANNEL_DRPDI_OUT    (drpdi_cpll_cal_int[(16*cal)+15:16*cal]),
          .GTHE3_CHANNEL_DRPEN_OUT    (drpen_cpll_cal_int[cal]),
          .GTHE3_CHANNEL_DRPWE_OUT    (drpwe_cpll_cal_int[cal]),
          .GTHE3_CHANNEL_DRPRDY_IN    (drprdy_int[cal]),
          .GTHE3_CHANNEL_DRPDO_IN     (drpdo_int[(16*cal)+15:16*cal])
        );
      end

      // Assign signals as appropriate to connect to the CPLL calibration block when it is instantiated
      assign txprgdivresetdone_out = txprgdivresetdone_cpll_cal_int;
      assign cplllock_int          = cplllock_cpll_cal_int;
      assign drprdy_out            = drprdy_cpll_cal_int;
      assign drpdo_out             = drpdo_cpll_cal_int;
      assign cpllreset_ch_int      = cpllreset_cpll_cal_int;
      assign cpllpd_ch_int         = cpllpd_cpll_cal_int;
      assign txprogdivreset_ch_int = txprogdivreset_cpll_cal_int;
      assign txoutclksel_ch_int    = txoutclksel_cpll_cal_int;
      assign drpaddr_ch_int        = drpaddr_cpll_cal_int;
      assign drpdi_ch_int          = drpdi_cpll_cal_int;
      assign drpen_ch_int          = drpen_cpll_cal_int;
      assign drpwe_ch_int          = drpwe_cpll_cal_int;
    end

    // Assign signals as appropriate to bypass the CPLL calibration block when it is not instantiated
    else begin : gen_no_cpll_cal
      assign txprgdivresetdone_out = txprgdivresetdone_int;
      assign cplllock_int          = cplllock_ch_int;
      assign drprdy_out            = drprdy_int;
      assign drpdo_out             = drpdo_int;
      assign cpllreset_ch_int      = cpllreset_int;
      assign cpllpd_ch_int         = cpllpd_int;
      assign txprogdivreset_ch_int = txprogdivreset_int;
      assign txoutclksel_ch_int    = txoutclksel_int;
      assign drpaddr_ch_int        = drpaddr_int;
      assign drpdi_ch_int          = drpdi_int;
      assign drpen_ch_int          = drpen_int;
      assign drpwe_ch_int          = drpwe_int;
    end


    // ----------------------------------------------------------------------------------------------------------------
    // Transceiver common block to channel block internal wiring
    // ----------------------------------------------------------------------------------------------------------------

    // If one or more transceiver common blocks are included within the bounds of the core, then connect the relevant
    // QPLL outputs of those blocks to the corresponding inputs of the channel blocks, on a per-quad basis. Otherwise,
    // drive the channel QPLL-related inputs with the corresponding core inputs.
    if (`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CM > 0) begin : gen_common_channel_wiring_internal
      genvar gi_ch_to_cm;
      for (gi_ch_to_cm = 0; gi_ch_to_cm < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH; gi_ch_to_cm = gi_ch_to_cm + 1) begin : gen_quad
        assign qpll0clk_int    [gi_ch_to_cm] = qpll0outclk_int    [f_idx_cm(gi_ch_to_cm)];
        assign qpll0refclk_int [gi_ch_to_cm] = qpll0outrefclk_int [f_idx_cm(gi_ch_to_cm)];
        assign qpll1clk_int    [gi_ch_to_cm] = qpll1outclk_int    [f_idx_cm(gi_ch_to_cm)];
        assign qpll1refclk_int [gi_ch_to_cm] = qpll1outrefclk_int [f_idx_cm(gi_ch_to_cm)];
      end
    end
    else begin : gen_common_channel_wiring_external
      assign qpll0clk_int    = qpll0clk_in;
      assign qpll0refclk_int = qpll0refclk_in;
      assign qpll1clk_int    = qpll1clk_in;
      assign qpll1refclk_int = qpll1refclk_in;
    end


    // ================================================================================================================
    // HELPER BLOCKS
    // ================================================================================================================

    // ----------------------------------------------------------------------------------------------------------------
    // Transmitter user clocking network helper block
    // ----------------------------------------------------------------------------------------------------------------

    // Include the helper block within the core
    if ((C_TX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_ENABLE__ENABLED) &&
        (C_LOCATE_TX_USER_CLOCKING == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_TX_USER_CLOCKING__CORE)) begin : gen_tx_user_clocking_internal

      // Generate a single module instance which is driven by a clock source associated with the master transmitter
      // channel, and which drives TXUSRCLK and TXUSRCLK2 for all channels
      if (C_TX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance

        // The source clock is TXOUTCLK from the master transmitter channel
        if (C_TX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_SOURCE__TXOUTCLK) begin : gen_txoutclk_source
          assign gtwiz_userclk_tx_srcclk_out = txoutclk_int[P_TX_MASTER_CH_PACKED_IDX];
        end

        // The source clock is the fabric-accessible output of the IBUFDS_GTE3 associated with the master transmitter
        // channel
        else if (C_TX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_SOURCE__IBUFDS) begin : gen_ibufds_source
          if (C_TX_PLL_TYPE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0) begin: gen_ibufds_source_qpll0
            assign gtwiz_userclk_tx_srcclk_out = gtrefclk00_int[f_idx_cm(P_TX_MASTER_CH_PACKED_IDX)];
          end
          else if (C_TX_PLL_TYPE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1) begin: gen_ibufds_source_qpll1
            assign gtwiz_userclk_tx_srcclk_out = gtrefclk01_int[f_idx_cm(P_TX_MASTER_CH_PACKED_IDX)];
          end
          else begin: gen_ibufds_source_cpll
            assign gtwiz_userclk_tx_srcclk_out = gtrefclk0_int[P_TX_MASTER_CH_PACKED_IDX];
          end
        end

        // Instantiate a single instance of the transmitter user clocking network helper block
        gtwizard_ultrascale_v1_6_2_gtwiz_userclk_tx #(
          .P_CONTENTS                     (C_TX_USER_CLOCKING_CONTENTS),
          .P_FREQ_RATIO_SOURCE_TO_USRCLK  (C_TX_OUTCLK_BUFG_GT_DIV),
          .P_FREQ_RATIO_USRCLK_TO_USRCLK2 (C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2)
        ) gtwiz_userclk_tx_inst (
          .gtwiz_userclk_tx_srcclk_in   (gtwiz_userclk_tx_srcclk_out),
          .gtwiz_userclk_tx_reset_in    (gtwiz_userclk_tx_reset_in),
          .gtwiz_userclk_tx_usrclk_out  (gtwiz_userclk_tx_usrclk_out),
          .gtwiz_userclk_tx_usrclk2_out (gtwiz_userclk_tx_usrclk2_out),
          .gtwiz_userclk_tx_active_out  (gtwiz_userclk_tx_active_out)
        );

        // Drive TXUSRCLK and TXUSRCLK2 for all channels with the respective helper block outputs
        assign txusrclk_int  = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_userclk_tx_usrclk_out}};
        assign txusrclk2_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_userclk_tx_usrclk2_out}};

      end

      // For each channel, generate one module instance which is driven by a clock source associated with that channel,
      // and which drives TXUSRCLK and TXUSRCLK2 for that same channel
      else if (C_TX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_INSTANCE_CTRL__PER_CHANNEL)
      begin : gen_per_channel_instance

        // Instantiate one instance of the transmitter user clocking network helper block for each channel
        genvar gi_hb_txclk;
        for (gi_hb_txclk = 0; gi_hb_txclk < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH; gi_hb_txclk = gi_hb_txclk + 1) begin : gen_gtwiz_userclk_tx

          // The source clock for a given instance is TXOUTCLK from the associated channel
          if (C_TX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_SOURCE__TXOUTCLK) begin : gen_txoutclk_source
            assign gtwiz_userclk_tx_srcclk_out[gi_hb_txclk] = txoutclk_int[gi_hb_txclk];
          end

          // The source clock for a given instance is the fabric-accessible output of the IBUFDS_GTE3 associated with that
          // channel
          else if (C_TX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_SOURCE__IBUFDS) begin : gen_ibufds_source
            if (C_TX_PLL_TYPE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0) begin: gen_ibufds_source_qpll0
              assign gtwiz_userclk_tx_srcclk_out[gi_hb_txclk] = gtrefclk00_int[f_idx_cm(gi_hb_txclk)];
            end
            else if (C_TX_PLL_TYPE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1) begin: gen_ibufds_source_qpll1
              assign gtwiz_userclk_tx_srcclk_out[gi_hb_txclk] = gtrefclk01_int[f_idx_cm(gi_hb_txclk)];
            end
            else begin: gen_ibufds_source_cpll
              assign gtwiz_userclk_tx_srcclk_out[gi_hb_txclk] = gtrefclk0_int[gi_hb_txclk];
            end
          end

          gtwizard_ultrascale_v1_6_2_gtwiz_userclk_tx #(
            .P_CONTENTS                     (C_TX_USER_CLOCKING_CONTENTS),
            .P_FREQ_RATIO_SOURCE_TO_USRCLK  (C_TX_OUTCLK_BUFG_GT_DIV),
            .P_FREQ_RATIO_USRCLK_TO_USRCLK2 (C_TX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2)
          ) gtwiz_userclk_tx_inst (
            .gtwiz_userclk_tx_srcclk_in   (gtwiz_userclk_tx_srcclk_out  [gi_hb_txclk]),
            .gtwiz_userclk_tx_reset_in    (gtwiz_userclk_tx_reset_in    [gi_hb_txclk]),
            .gtwiz_userclk_tx_usrclk_out  (gtwiz_userclk_tx_usrclk_out  [gi_hb_txclk]),
            .gtwiz_userclk_tx_usrclk2_out (gtwiz_userclk_tx_usrclk2_out [gi_hb_txclk]),
            .gtwiz_userclk_tx_active_out  (gtwiz_userclk_tx_active_out  [gi_hb_txclk])
          );
        end

        // Drive TXUSRCLK and TXUSRCLK2 for each channel with the respective outputs of the associated helper block
        assign txusrclk_int  = gtwiz_userclk_tx_usrclk_out;
        assign txusrclk2_int = gtwiz_userclk_tx_usrclk2_out;

      end

    end

    // Do not include the helper block within the core
    else begin : gen_tx_user_clocking_external

      if (C_TX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance
        assign gtwiz_userclk_tx_srcclk_out  = 1'b0;
        assign gtwiz_userclk_tx_usrclk_out  = 1'b0;
        assign gtwiz_userclk_tx_usrclk2_out = 1'b0;
      end
      else begin : gen_per_channel_instance
        assign gtwiz_userclk_tx_srcclk_out  = {(C_TX_USER_CLOCKING_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
        assign gtwiz_userclk_tx_usrclk_out  = {(C_TX_USER_CLOCKING_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
        assign gtwiz_userclk_tx_usrclk2_out = {(C_TX_USER_CLOCKING_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
      end

      assign gtwiz_userclk_tx_active_out = gtwiz_userclk_tx_active_in;
      assign txusrclk_int                = txusrclk_in;
      assign txusrclk2_int               = txusrclk2_in;
    end


    // ----------------------------------------------------------------------------------------------------------------
    // Receiver user clocking network helper block
    // ----------------------------------------------------------------------------------------------------------------

    // Include the helper block within the core
    if ((C_RX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_ENABLE__ENABLED) &&
        (C_LOCATE_RX_USER_CLOCKING == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RX_USER_CLOCKING__CORE)) begin : gen_rx_user_clocking_internal

      // Generate a single module instance which is driven by a clock source associated with the master receiver
      // channel, and which drives RXUSRCLK and RXUSRCLK2 for all channels
      if (C_RX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance

        // The source clock is RXOUTCLK from the master receiver channel
        if (C_RX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__RXOUTCLK) begin : gen_rxoutclk_source
          assign gtwiz_userclk_rx_srcclk_out = rxoutclk_int[P_RX_MASTER_CH_PACKED_IDX];
        end

        // The source clock is the fabric-accessible output of the IBUFDS_GTE3 associated with the master receiver
        // channel
        else if (C_RX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__IBUFDS) begin : gen_ibufds_source
          if (C_RX_PLL_TYPE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0) begin: gen_ibufds_source_qpll0
            assign gtwiz_userclk_rx_srcclk_out = gtrefclk00_int[f_idx_cm(P_RX_MASTER_CH_PACKED_IDX)];
          end
          else if (C_RX_PLL_TYPE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1) begin: gen_ibufds_source_qpll1
            assign gtwiz_userclk_rx_srcclk_out = gtrefclk01_int[f_idx_cm(P_RX_MASTER_CH_PACKED_IDX)];
          end
          else begin: gen_ibufds_source_cpll
            assign gtwiz_userclk_rx_srcclk_out = gtrefclk0_int[P_RX_MASTER_CH_PACKED_IDX];
          end
        end

        // The source clock is TXOUTCLK from the master transmitter channel
        else if (C_RX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__TXOUTCLK) begin : gen_txoutclk_source
          assign gtwiz_userclk_rx_srcclk_out = txoutclk_int[P_TX_MASTER_CH_PACKED_IDX];
        end

        // Instantiate a single instance of the receiver user clocking network helper block
        gtwizard_ultrascale_v1_6_2_gtwiz_userclk_rx #(
          .P_CONTENTS                     (C_RX_USER_CLOCKING_CONTENTS),
          .P_FREQ_RATIO_SOURCE_TO_USRCLK  (C_RX_OUTCLK_BUFG_GT_DIV),
          .P_FREQ_RATIO_USRCLK_TO_USRCLK2 (C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2)
        ) gtwiz_userclk_rx_inst (
          .gtwiz_userclk_rx_srcclk_in   (gtwiz_userclk_rx_srcclk_out),
          .gtwiz_userclk_rx_reset_in    (gtwiz_userclk_rx_reset_in),
          .gtwiz_userclk_rx_usrclk_out  (gtwiz_userclk_rx_usrclk_out),
          .gtwiz_userclk_rx_usrclk2_out (gtwiz_userclk_rx_usrclk2_out),
          .gtwiz_userclk_rx_active_out  (gtwiz_userclk_rx_active_out)
        );

        // Drive RXUSRCLK and RXUSRCLK2 for all channels with the respective helper block outputs
        assign rxusrclk_int  = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_userclk_rx_usrclk_out}};
        assign rxusrclk2_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_userclk_rx_usrclk2_out}};

      end

      // For each channel, generate one module instance which is driven by a clock source associated with that channel,
      // and which drives RXUSRCLK and RXUSRCLK2 for that same channel
      else if (C_RX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_INSTANCE_CTRL__PER_CHANNEL)
      begin : gen_per_channel_instance

        // Instantiate one instance of the receiver user clocking network helper block for each channel
        genvar gi_hb_rxclk;
        for (gi_hb_rxclk = 0; gi_hb_rxclk < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH; gi_hb_rxclk = gi_hb_rxclk + 1) begin : gen_gtwiz_userclk_rx

          // The source clock for a given instance is RXOUTCLK from the associated channel
          if (C_RX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__RXOUTCLK) begin : gen_rxoutclk_source
            assign gtwiz_userclk_rx_srcclk_out[gi_hb_rxclk] = rxoutclk_int[gi_hb_rxclk];
          end

          // The source clock for a given instance is the fabric-accessible output of the IBUFDS_GTE3 associated with that
          // channel
          else if (C_RX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__IBUFDS) begin : gen_ibufds_source
            if (C_RX_PLL_TYPE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0) begin: gen_ibufds_source_qpll0
              assign gtwiz_userclk_rx_srcclk_out[gi_hb_rxclk] = gtrefclk00_int[f_idx_cm(gi_hb_rxclk)];
            end
            else if (C_RX_PLL_TYPE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1) begin: gen_ibufds_source_qpll1
              assign gtwiz_userclk_rx_srcclk_out[gi_hb_rxclk] = gtrefclk01_int[f_idx_cm(gi_hb_rxclk)];
            end
            else begin: gen_ibufds_source_cpll
              assign gtwiz_userclk_rx_srcclk_out[gi_hb_rxclk] = gtrefclk0_int[gi_hb_rxclk];
            end
          end

          // The source clock for a given instance is TXOUTCLK from the associated channel
          else if (C_RX_USER_CLOCKING_SOURCE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_SOURCE__TXOUTCLK) begin : gen_txoutclk_source
            assign gtwiz_userclk_rx_srcclk_out[gi_hb_rxclk] = txoutclk_int[gi_hb_rxclk];
          end

          gtwizard_ultrascale_v1_6_2_gtwiz_userclk_rx #(
            .P_CONTENTS                     (C_RX_USER_CLOCKING_CONTENTS),
            .P_FREQ_RATIO_SOURCE_TO_USRCLK  (C_RX_OUTCLK_BUFG_GT_DIV),
            .P_FREQ_RATIO_USRCLK_TO_USRCLK2 (C_RX_USER_CLOCKING_RATIO_FUSRCLK_FUSRCLK2)
          ) gtwiz_userclk_rx_inst (
            .gtwiz_userclk_rx_srcclk_in   (gtwiz_userclk_rx_srcclk_out  [gi_hb_rxclk]),
            .gtwiz_userclk_rx_reset_in    (gtwiz_userclk_rx_reset_in    [gi_hb_rxclk]),
            .gtwiz_userclk_rx_usrclk_out  (gtwiz_userclk_rx_usrclk_out  [gi_hb_rxclk]),
            .gtwiz_userclk_rx_usrclk2_out (gtwiz_userclk_rx_usrclk2_out [gi_hb_rxclk]),
            .gtwiz_userclk_rx_active_out  (gtwiz_userclk_rx_active_out  [gi_hb_rxclk])
          );
        end

        // Drive RXUSRCLK and RXUSRCLK2 for each channel with the respective outputs of the associated helper block
        assign rxusrclk_int  = gtwiz_userclk_rx_usrclk_out;
        assign rxusrclk2_int = gtwiz_userclk_rx_usrclk2_out;

      end

    end

    // Do not include the helper block within the core
    else begin : gen_rx_user_clocking_external

      if (C_RX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance
        assign gtwiz_userclk_rx_srcclk_out  = 1'b0;
        assign gtwiz_userclk_rx_usrclk_out  = 1'b0;
        assign gtwiz_userclk_rx_usrclk2_out = 1'b0;
      end
      else begin : gen_per_channel_instance
        assign gtwiz_userclk_rx_srcclk_out  = {(C_RX_USER_CLOCKING_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
        assign gtwiz_userclk_rx_usrclk_out  = {(C_RX_USER_CLOCKING_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
        assign gtwiz_userclk_rx_usrclk2_out = {(C_RX_USER_CLOCKING_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
      end

      assign gtwiz_userclk_rx_active_out = gtwiz_userclk_rx_active_in;
      assign rxusrclk_int                = rxusrclk_in;
      assign rxusrclk2_int               = rxusrclk2_in;
    end


    // ----------------------------------------------------------------------------------------------------------------
    // Transmitter buffer bypass controller helper block
    // ----------------------------------------------------------------------------------------------------------------

    // Include the helper block within the core
    if ((C_TX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_ENABLE__ENABLED) &&
        (C_TX_BUFFER_MODE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_MODE__BYPASS) &&
        (C_LOCATE_TX_BUFFER_BYPASS_CONTROLLER == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_TX_BUFFER_BYPASS_CONTROLLER__CORE))
        begin : gen_tx_buffer_bypass_internal

      // Generate a single module instance which uses the designated transmitter master channel as the transmit buffer
      // bypass master channel, and all other channels as transmit buffer bypass slave channels
      if (C_TX_BUFFER_BYPASS_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_BYPASS_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance

        // Depending on the number of reset controller helper blocks, either use the single reset done indicator or the
        // logical combination of per-channel reset done indicators as the reset done indicator for use in this block
        wire gtwiz_buffbypass_tx_resetdone_int;

        if (C_RESET_CONTROLLER_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__SINGLE_INSTANCE)
        begin : gen_resetdone_single_instance
          assign gtwiz_buffbypass_tx_resetdone_int = gtwiz_reset_tx_done_out;
        end
        else begin : gen_resetdone_per_channel_instance
          assign gtwiz_buffbypass_tx_resetdone_int = &gtwiz_reset_tx_done_out;
        end

        gtwizard_ultrascale_v1_6_2_gtwiz_buffbypass_tx #(
          .P_BUFFER_BYPASS_MODE       (C_TX_BUFFBYPASS_MODE),
          .P_TOTAL_NUMBER_OF_CHANNELS (C_TOTAL_NUM_CHANNELS),
          .P_MASTER_CHANNEL_POINTER   (P_TX_MASTER_CH_PACKED_IDX)
        ) gtwiz_buffbypass_tx_inst (
          .gtwiz_buffbypass_tx_clk_in        (txusrclk2_int[P_TX_MASTER_CH_PACKED_IDX]),
          .gtwiz_buffbypass_tx_reset_in      (gtwiz_buffbypass_tx_reset_in),
          .gtwiz_buffbypass_tx_start_user_in (gtwiz_buffbypass_tx_start_user_in),
          .gtwiz_buffbypass_tx_resetdone_in  (gtwiz_buffbypass_tx_resetdone_int),
          .gtwiz_buffbypass_tx_done_out      (gtwiz_buffbypass_tx_done_out),
          .gtwiz_buffbypass_tx_error_out     (gtwiz_buffbypass_tx_error_out),
          .txphaligndone_in                  (txphaligndone_int),
          .txphinitdone_in                   (txphinitdone_int),
          .txdlysresetdone_in                (txdlysresetdone_int),
          .txsyncout_in                      (txsyncout_int),
          .txsyncdone_in                     (txsyncdone_int),
          .txphdlyreset_out                  (txphdlyreset_int),
          .txphalign_out                     (txphalign_int),
          .txphalignen_out                   (txphalignen_int),
          .txphdlypd_out                     (txphdlypd_int),
          .txphinit_out                      (txphinit_int),
          .txphovrden_out                    (txphovrden_int),
          .txdlysreset_out                   (txdlysreset_int),
          .txdlybypass_out                   (txdlybypass_int),
          .txdlyen_out                       (txdlyen_int),
          .txdlyovrden_out                   (txdlyovrden_int),
          .txphdlytstclk_out                 (txphdlytstclk_int),
          .txdlyhold_out                     (txdlyhold_int),
          .txdlyupdown_out                   (txdlyupdown_int),
          .txsyncmode_out                    (txsyncmode_int),
          .txsyncallin_out                   (txsyncallin_int),
          .txsyncin_out                      (txsyncin_int)
        );

      end

      // Generate one module instance per channel to implement single-lane transmit buffer bypass for each lane
      // independently, treating each lane as a master
      else if (C_TX_BUFFER_BYPASS_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_BYPASS_INSTANCE_CTRL__PER_CHANNEL)
      begin : gen_per_channel_instance

        // Depending on the number of reset controller helper blocks, either use the single reset done indicator or the
        // logical combination of per-channel reset done indicators as the reset done indicator for use in this block
        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] gtwiz_buffbypass_tx_resetdone_int;

        if (C_RESET_CONTROLLER_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__SINGLE_INSTANCE)
        begin : gen_resetdone_single_instance
          assign gtwiz_buffbypass_tx_resetdone_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_tx_done_out}};
        end
        else begin : gen_resetdone_per_channel_instance
          assign gtwiz_buffbypass_tx_resetdone_int = gtwiz_reset_tx_done_out;
        end

        genvar gi_hb_txbb;
        for (gi_hb_txbb = 0; gi_hb_txbb < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH; gi_hb_txbb = gi_hb_txbb + 1) begin : gen_gtwiz_buffbypass_tx
          gtwizard_ultrascale_v1_6_2_gtwiz_buffbypass_tx #(
            .P_BUFFER_BYPASS_MODE       (C_TX_BUFFBYPASS_MODE),
            .P_TOTAL_NUMBER_OF_CHANNELS (1),
            .P_MASTER_CHANNEL_POINTER   (0)
          ) gtwiz_buffbypass_tx_inst (
            .gtwiz_buffbypass_tx_clk_in        (txusrclk2_int                     [gi_hb_txbb]),
            .gtwiz_buffbypass_tx_reset_in      (gtwiz_buffbypass_tx_reset_in      [gi_hb_txbb]),
            .gtwiz_buffbypass_tx_start_user_in (gtwiz_buffbypass_tx_start_user_in [gi_hb_txbb]),
            .gtwiz_buffbypass_tx_resetdone_in  (gtwiz_buffbypass_tx_resetdone_int [gi_hb_txbb]),
            .gtwiz_buffbypass_tx_done_out      (gtwiz_buffbypass_tx_done_out      [gi_hb_txbb]),
            .gtwiz_buffbypass_tx_error_out     (gtwiz_buffbypass_tx_error_out     [gi_hb_txbb]),
            .txphaligndone_in                  (txphaligndone_int                 [gi_hb_txbb]),
            .txphinitdone_in                   (txphinitdone_int                  [gi_hb_txbb]),
            .txdlysresetdone_in                (txdlysresetdone_int               [gi_hb_txbb]),
            .txsyncout_in                      (txsyncout_int                     [gi_hb_txbb]),
            .txsyncdone_in                     (txsyncdone_int                    [gi_hb_txbb]),
            .txphdlyreset_out                  (txphdlyreset_int                  [gi_hb_txbb]),
            .txphalign_out                     (txphalign_int                     [gi_hb_txbb]),
            .txphalignen_out                   (txphalignen_int                   [gi_hb_txbb]),
            .txphdlypd_out                     (txphdlypd_int                     [gi_hb_txbb]),
            .txphinit_out                      (txphinit_int                      [gi_hb_txbb]),
            .txphovrden_out                    (txphovrden_int                    [gi_hb_txbb]),
            .txdlysreset_out                   (txdlysreset_int                   [gi_hb_txbb]),
            .txdlybypass_out                   (txdlybypass_int                   [gi_hb_txbb]),
            .txdlyen_out                       (txdlyen_int                       [gi_hb_txbb]),
            .txdlyovrden_out                   (txdlyovrden_int                   [gi_hb_txbb]),
            .txphdlytstclk_out                 (txphdlytstclk_int                 [gi_hb_txbb]),
            .txdlyhold_out                     (txdlyhold_int                     [gi_hb_txbb]),
            .txdlyupdown_out                   (txdlyupdown_int                   [gi_hb_txbb]),
            .txsyncmode_out                    (txsyncmode_int                    [gi_hb_txbb]),
            .txsyncallin_out                   (txsyncallin_int                   [gi_hb_txbb]),
            .txsyncin_out                      (txsyncin_int                      [gi_hb_txbb])
          );
        end

      end

    end

    // Do not include the helper block within the core
    else begin : gen_no_or_external_tx_buffer_bypass

      if (C_TX_BUFFER_BYPASS_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_BUFFER_BYPASS_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance
        assign gtwiz_buffbypass_tx_done_out  = 1'b0;
        assign gtwiz_buffbypass_tx_error_out = 1'b0;
      end
      else begin : gen_per_channel_instance
        assign gtwiz_buffbypass_tx_done_out  = {(C_TX_BUFFER_BYPASS_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
        assign gtwiz_buffbypass_tx_error_out = {(C_TX_BUFFER_BYPASS_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
      end

      assign txphdlyreset_int  = txphdlyreset_in;
      assign txphalign_int     = txphalign_in;
      assign txphalignen_int   = txphalignen_in;
      assign txphdlypd_int     = txphdlypd_in;
      assign txphinit_int      = txphinit_in;
      assign txphovrden_int    = txphovrden_in;
      assign txdlysreset_int   = txdlysreset_in;
      assign txdlybypass_int   = txdlybypass_in;
      assign txdlyen_int       = txdlyen_in;
      assign txdlyovrden_int   = txdlyovrden_in;
      assign txphdlytstclk_int = txphdlytstclk_in;
      assign txdlyhold_int     = txdlyhold_in;
      assign txdlyupdown_int   = txdlyupdown_in;
      assign txsyncmode_int    = txsyncmode_in;
      assign txsyncallin_int   = txsyncallin_in;
      assign txsyncin_int      = txsyncin_in;

    end


    // ----------------------------------------------------------------------------------------------------------------
    // Receiver buffer bypass controller helper block
    // ----------------------------------------------------------------------------------------------------------------

    // Include the helper block within the core
    if ((C_RX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_ENABLE__ENABLED) &&
        (C_RX_BUFFER_MODE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_MODE__BYPASS) &&
        (C_LOCATE_RX_BUFFER_BYPASS_CONTROLLER == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RX_BUFFER_BYPASS_CONTROLLER__CORE))
        begin : gen_rx_buffer_bypass_internal

      // Generate a single module instance which uses the designated receiver master channel as the receive buffer
      // bypass master channel, and all other channels as receive buffer bypass slave channels
      if (C_RX_BUFFER_BYPASS_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_BYPASS_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance

        // Depending on the number of reset controller helper blocks, either use the single reset done indicator or the
        // logical combination of per-channel reset done indicators as the reset done indicator for use in this block
        wire gtwiz_buffbypass_rx_resetdone_int;

        if (C_RESET_CONTROLLER_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__SINGLE_INSTANCE)
        begin : gen_resetdone_single_instance
          assign gtwiz_buffbypass_rx_resetdone_int = gtwiz_reset_rx_done_out;
        end
        else begin : gen_resetdone_per_channel_instance
          assign gtwiz_buffbypass_rx_resetdone_int = &gtwiz_reset_rx_done_out;
        end

        gtwizard_ultrascale_v1_6_2_gtwiz_buffbypass_rx #(
          .P_BUFFER_BYPASS_MODE       (C_RX_BUFFBYPASS_MODE),
          .P_TOTAL_NUMBER_OF_CHANNELS (C_TOTAL_NUM_CHANNELS),
          .P_MASTER_CHANNEL_POINTER   (P_RX_MASTER_CH_PACKED_IDX)
        ) gtwiz_buffbypass_rx_inst (
          .gtwiz_buffbypass_rx_clk_in        (rxusrclk2_int[P_RX_MASTER_CH_PACKED_IDX]),
          .gtwiz_buffbypass_rx_reset_in      (gtwiz_buffbypass_rx_reset_in),
          .gtwiz_buffbypass_rx_start_user_in (gtwiz_buffbypass_rx_start_user_in),
          .gtwiz_buffbypass_rx_resetdone_in  (gtwiz_buffbypass_rx_resetdone_int),
          .gtwiz_buffbypass_rx_done_out      (gtwiz_buffbypass_rx_done_out),
          .gtwiz_buffbypass_rx_error_out     (gtwiz_buffbypass_rx_error_out),
          .rxphaligndone_in                  (rxphaligndone_int),
          .rxdlysresetdone_in                (rxdlysresetdone_int),
          .rxsyncout_in                      (rxsyncout_int),
          .rxsyncdone_in                     (rxsyncdone_int),
          .rxphdlyreset_out                  (rxphdlyreset_int),
          .rxphalign_out                     (rxphalign_int),
          .rxphalignen_out                   (rxphalignen_int),
          .rxphdlypd_out                     (rxphdlypd_int),
          .rxphovrden_out                    (rxphovrden_int),
          .rxdlysreset_out                   (rxdlysreset_int),
          .rxdlybypass_out                   (rxdlybypass_int),
          .rxdlyen_out                       (rxdlyen_int),
          .rxdlyovrden_out                   (rxdlyovrden_int),
          .rxsyncmode_out                    (rxsyncmode_int),
          .rxsyncallin_out                   (rxsyncallin_int),
          .rxsyncin_out                      (rxsyncin_int)
        );

      end

      // Generate one module instance per channel to implement single-lane receive buffer bypass for each lane
      // independently, treating each lane as a master
      else if (C_RX_BUFFER_BYPASS_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_BYPASS_INSTANCE_CTRL__PER_CHANNEL)
      begin : gen_per_channel_instance

        // Depending on the number of reset controller helper blocks, either use the single reset done indicator or the
        // logical combination of per-channel reset done indicators as the reset done indicator for use in this block
        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] gtwiz_buffbypass_rx_resetdone_int;

        if (C_RESET_CONTROLLER_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__SINGLE_INSTANCE)
        begin : gen_resetdone_single_instance
          assign gtwiz_buffbypass_rx_resetdone_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_rx_done_out}};
        end
        else begin : gen_resetdone_per_channel_instance
          assign gtwiz_buffbypass_rx_resetdone_int = gtwiz_reset_rx_done_out;
        end

        genvar gi_hb_rxbb;
        for (gi_hb_rxbb = 0; gi_hb_rxbb < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH; gi_hb_rxbb = gi_hb_rxbb + 1) begin : gen_gtwiz_buffbypass_rx
          gtwizard_ultrascale_v1_6_2_gtwiz_buffbypass_rx #(
            .P_BUFFER_BYPASS_MODE       (C_RX_BUFFBYPASS_MODE),
            .P_TOTAL_NUMBER_OF_CHANNELS (1),
            .P_MASTER_CHANNEL_POINTER   (0)
          ) gtwiz_buffbypass_rx_inst (
            .gtwiz_buffbypass_rx_clk_in        (rxusrclk2_int                     [gi_hb_rxbb]),
            .gtwiz_buffbypass_rx_reset_in      (gtwiz_buffbypass_rx_reset_in      [gi_hb_rxbb]),
            .gtwiz_buffbypass_rx_start_user_in (gtwiz_buffbypass_rx_start_user_in [gi_hb_rxbb]),
            .gtwiz_buffbypass_rx_resetdone_in  (gtwiz_buffbypass_rx_resetdone_int [gi_hb_rxbb]),
            .gtwiz_buffbypass_rx_done_out      (gtwiz_buffbypass_rx_done_out      [gi_hb_rxbb]),
            .gtwiz_buffbypass_rx_error_out     (gtwiz_buffbypass_rx_error_out     [gi_hb_rxbb]),
            .rxphaligndone_in                  (rxphaligndone_int                 [gi_hb_rxbb]),
            .rxdlysresetdone_in                (rxdlysresetdone_int               [gi_hb_rxbb]),
            .rxsyncout_in                      (rxsyncout_int                     [gi_hb_rxbb]),
            .rxsyncdone_in                     (rxsyncdone_int                    [gi_hb_rxbb]),
            .rxphdlyreset_out                  (rxphdlyreset_int                  [gi_hb_rxbb]),
            .rxphalign_out                     (rxphalign_int                     [gi_hb_rxbb]),
            .rxphalignen_out                   (rxphalignen_int                   [gi_hb_rxbb]),
            .rxphdlypd_out                     (rxphdlypd_int                     [gi_hb_rxbb]),
            .rxphovrden_out                    (rxphovrden_int                    [gi_hb_rxbb]),
            .rxdlysreset_out                   (rxdlysreset_int                   [gi_hb_rxbb]),
            .rxdlybypass_out                   (rxdlybypass_int                   [gi_hb_rxbb]),
            .rxdlyen_out                       (rxdlyen_int                       [gi_hb_rxbb]),
            .rxdlyovrden_out                   (rxdlyovrden_int                   [gi_hb_rxbb]),
            .rxsyncmode_out                    (rxsyncmode_int                    [gi_hb_rxbb]),
            .rxsyncallin_out                   (rxsyncallin_int                   [gi_hb_rxbb]),
            .rxsyncin_out                      (rxsyncin_int                      [gi_hb_rxbb])
          );
        end

      end

    end

    // Do not include the helper block within the core
    else begin : gen_no_or_external_rx_buffer_bypass

      if (C_RX_BUFFER_BYPASS_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_BUFFER_BYPASS_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance
        assign gtwiz_buffbypass_rx_done_out  = 1'b0;
        assign gtwiz_buffbypass_rx_error_out = 1'b0;
      end
      else begin : gen_per_channel_instance
        assign gtwiz_buffbypass_rx_done_out  = {(C_RX_BUFFER_BYPASS_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
        assign gtwiz_buffbypass_rx_error_out = {(C_RX_BUFFER_BYPASS_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
      end

      assign rxphdlyreset_int = rxphdlyreset_in;
      assign rxphalign_int    = rxphalign_in;
      assign rxphalignen_int  = rxphalignen_in;
      assign rxphdlypd_int    = rxphdlypd_in;
      assign rxphovrden_int   = rxphovrden_in;
      assign rxdlysreset_int  = rxdlysreset_in;
      assign rxdlybypass_int  = rxdlybypass_in;
      assign rxdlyen_int      = rxdlyen_in;
      assign rxdlyovrden_int  = rxdlyovrden_in;
      assign rxsyncmode_int   = rxsyncmode_in;
      assign rxsyncallin_int  = rxsyncallin_in;
      assign rxsyncin_int     = rxsyncin_in;

    end


    // ----------------------------------------------------------------------------------------------------------------
    // Reset controller helper block
    // ----------------------------------------------------------------------------------------------------------------

    // Include the helper block within the core
    if (C_LOCATE_RESET_CONTROLLER == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_RESET_CONTROLLER__CORE) begin : gen_reset_controller_internal

      // Generate a single module instance which controls all PLLs and all channels within the core
      if (C_RESET_CONTROLLER_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance

        // Depending on the number of user clocking network helper blocks, either use the single user clock active
        // indicator or a logical combination of per-channel user clock active indicators as the user clock active
        // indicator for use in this block
        wire gtwiz_reset_userclk_tx_active_int;
        wire gtwiz_reset_userclk_rx_active_int;

        if (C_TX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE)
        begin : gen_txuserclkactive_single_instance
          assign gtwiz_reset_userclk_tx_active_int = gtwiz_userclk_tx_active_out;
        end
        else begin : gen_txuserclkactive_per_channel_instance
          assign gtwiz_reset_userclk_tx_active_int = &gtwiz_userclk_tx_active_out;
        end
        if (C_RX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE)
        begin : gen_rxuserclkactive_single_instance
          assign gtwiz_reset_userclk_rx_active_int = gtwiz_userclk_rx_active_out;
        end
        else begin : gen_rxuserclkactive_per_channel_instance

          // When each channel has an independent receiver user clock, synchronize each receiver user clock active
          // indicator independently before combining them
          wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] gtwiz_userclk_rx_active_sync;

          genvar gi_ch_rxclk;
          for (gi_ch_rxclk = 0; gi_ch_rxclk < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH; gi_ch_rxclk = gi_ch_rxclk + 1) begin : gen_ch_rxclk
            gtwizard_ultrascale_v1_6_2_bit_synchronizer bit_synchronizer_gtwiz_reset_userclk_rx_active_inst (
              .clk_in (gtwiz_reset_clk_freerun_in),
              .i_in   (gtwiz_userclk_rx_active_out[gi_ch_rxclk]),
              .o_out  (gtwiz_userclk_rx_active_sync[gi_ch_rxclk])
            );
          end
          assign gtwiz_reset_userclk_rx_active_int = &gtwiz_userclk_rx_active_sync;
        end

        wire gtwiz_reset_gtpowergood_int;
        wire gtwiz_reset_plllock_tx_int;
        wire gtwiz_reset_txresetdone_int;
        wire gtwiz_reset_plllock_rx_int;
        wire gtwiz_reset_rxcdrlock_int;
        wire gtwiz_reset_rxresetdone_int;
        wire gtwiz_reset_pllreset_tx_int;
        wire gtwiz_reset_txprogdivreset_int;
        wire gtwiz_reset_gttxreset_int;
        wire gtwiz_reset_txuserrdy_int;
        wire gtwiz_reset_pllreset_rx_int;
        wire gtwiz_reset_rxprogdivreset_int;
        wire gtwiz_reset_gtrxreset_int;
        wire gtwiz_reset_rxuserrdy_int;

        // Combine the appropriate PLL lock signals such that the reset controller can sense when all PLLs which clock
        // each data direction are locked, regardless of what PLL source is used
        case (C_TX_PLL_TYPE)
          `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0: assign gtwiz_reset_plllock_tx_int = &qpll0lock_int;
          `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1: assign gtwiz_reset_plllock_tx_int = &qpll1lock_int;
          `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL:  assign gtwiz_reset_plllock_tx_int = &cplllock_int;
        endcase
        case (C_RX_PLL_TYPE)
          `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0: assign gtwiz_reset_plllock_rx_int = &qpll0lock_int;
          `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1: assign gtwiz_reset_plllock_rx_int = &qpll1lock_int;
          `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL:  assign gtwiz_reset_plllock_rx_int = &cplllock_int;
        endcase

        // Combine the power good, reset done, and CDR lock indicators across all channels, per data direction
        assign gtwiz_reset_gtpowergood_int = &gtpowergood_int;
        assign gtwiz_reset_rxcdrlock_int   = &rxcdrlock_int;

        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] txresetdone_sync;
        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] rxresetdone_sync;
        genvar gi_ch_xrd;
        for (gi_ch_xrd = 0; gi_ch_xrd < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH; gi_ch_xrd = gi_ch_xrd + 1) begin : gen_ch_xrd
          gtwizard_ultrascale_v1_6_2_bit_synchronizer bit_synchronizer_txresetdone_inst (
            .clk_in (gtwiz_reset_clk_freerun_in),
            .i_in   (txresetdone_int[gi_ch_xrd]),
            .o_out  (txresetdone_sync[gi_ch_xrd])
          );
          gtwizard_ultrascale_v1_6_2_bit_synchronizer bit_synchronizer_rxresetdone_inst (
            .clk_in (gtwiz_reset_clk_freerun_in),
            .i_in   (rxresetdone_int[gi_ch_xrd]),
            .o_out  (rxresetdone_sync[gi_ch_xrd])
          );
        end
        assign gtwiz_reset_txresetdone_int = &txresetdone_sync;
        assign gtwiz_reset_rxresetdone_int = &rxresetdone_sync;

        // Assign tie-off values for use in reset controller state machine traversal
        wire gtwiz_reset_tx_enabled_tie_int;
        wire gtwiz_reset_rx_enabled_tie_int;
        wire gtwiz_reset_shared_pll_tie_int;

        if (C_TX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_ENABLE__ENABLED)
        begin : gen_reset_tx_enabled_tie_high
          assign gtwiz_reset_tx_enabled_tie_int = 1'b1;
        end
        else begin : gen_reset_tx_enabled_tie_low
          assign gtwiz_reset_tx_enabled_tie_int = 1'b0;
        end

        if (C_RX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_ENABLE__ENABLED)
        begin : gen_reset_rx_enabled_tie_high
          assign gtwiz_reset_rx_enabled_tie_int = 1'b1;
        end
        else begin : gen_reset_rx_enabled_tie_low
          assign gtwiz_reset_rx_enabled_tie_int = 1'b0;
        end

        if (C_TX_PLL_TYPE == C_RX_PLL_TYPE)
        begin : gen_reset_shared_pll_tie_high
          assign gtwiz_reset_shared_pll_tie_int = 1'b1;
        end
        else begin : gen_reset_shared_pll_tie_low
          assign gtwiz_reset_shared_pll_tie_int = 1'b0;
        end

        // Instantiate the single reset controller
        gtwizard_ultrascale_v1_6_2_gtwiz_reset #(
          .P_FREERUN_FREQUENCY       (C_FREERUN_FREQUENCY),
          .P_USE_CPLL_CAL            (P_USE_CPLL_CAL),
          .P_TX_PLL_TYPE             (C_TX_PLL_TYPE),
          .P_RX_PLL_TYPE             (C_RX_PLL_TYPE),
          .P_RX_LINE_RATE            (C_RX_LINE_RATE),
          .P_CDR_TIMEOUT_FREERUN_CYC (P_CDR_TIMEOUT_FREERUN_CYC)
        ) gtwiz_reset_inst (
          .gtwiz_reset_clk_freerun_in         (gtwiz_reset_clk_freerun_in),
          .gtwiz_reset_all_in                 (gtwiz_reset_all_in),
          .gtwiz_reset_tx_pll_and_datapath_in (gtwiz_reset_tx_pll_and_datapath_in),
          .gtwiz_reset_tx_datapath_in         (gtwiz_reset_tx_datapath_in),
          .gtwiz_reset_rx_pll_and_datapath_in (gtwiz_reset_rx_pll_and_datapath_in),
          .gtwiz_reset_rx_datapath_in         (gtwiz_reset_rx_datapath_in),
          .gtwiz_reset_rx_cdr_stable_out      (gtwiz_reset_rx_cdr_stable_out),
          .gtwiz_reset_tx_done_out            (gtwiz_reset_tx_done_out),
          .gtwiz_reset_rx_done_out            (gtwiz_reset_rx_done_out),
          .gtwiz_reset_userclk_tx_active_in   (gtwiz_reset_userclk_tx_active_int),
          .gtwiz_reset_userclk_rx_active_in   (gtwiz_reset_userclk_rx_active_int),
          .gtpowergood_in                     (gtwiz_reset_gtpowergood_int),
          .txusrclk2_in                       (txusrclk2_int[P_TX_MASTER_CH_PACKED_IDX]),
          .plllock_tx_in                      (gtwiz_reset_plllock_tx_int),
          .txresetdone_in                     (gtwiz_reset_txresetdone_int),
          .rxusrclk2_in                       (rxusrclk2_int[P_RX_MASTER_CH_PACKED_IDX]),
          .plllock_rx_in                      (gtwiz_reset_plllock_rx_int),
          .rxcdrlock_in                       (gtwiz_reset_rxcdrlock_int),
          .rxresetdone_in                     (gtwiz_reset_rxresetdone_int),
          .pllreset_tx_out                    (gtwiz_reset_pllreset_tx_int),
          .txprogdivreset_out                 (gtwiz_reset_txprogdivreset_int),
          .gttxreset_out                      (gtwiz_reset_gttxreset_int),
          .txuserrdy_out                      (gtwiz_reset_txuserrdy_int),
          .pllreset_rx_out                    (gtwiz_reset_pllreset_rx_int),
          .rxprogdivreset_out                 (gtwiz_reset_rxprogdivreset_int),
          .gtrxreset_out                      (gtwiz_reset_gtrxreset_int),
          .rxuserrdy_out                      (gtwiz_reset_rxuserrdy_int),
          .tx_enabled_tie_in                  (gtwiz_reset_tx_enabled_tie_int),
          .rx_enabled_tie_in                  (gtwiz_reset_rx_enabled_tie_int),
          .shared_pll_tie_in                  (gtwiz_reset_shared_pll_tie_int)
        );

        // Drive the internal PLL reset inputs with the appropriate PLL reset signals produced by the reset controller.
        // The single reset controller instance generates independent transmit PLL reset and receive PLL reset outputs,
        // which are used across all such PLLs in the core.
        if ((C_GT_REV == 11) || (C_GT_REV == 12) || (C_GT_REV == 14) || (C_GT_REV == 16)) begin : gen_rst_assign_es
          case ({C_TX_PLL_TYPE, C_RX_PLL_TYPE})
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}: begin : gen_txqpll0_rxqpll0
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int || gtwiz_reset_pllreset_rx_int}};
              assign qpll1reset_int = qpll1reset_in;
              assign cpllreset_int  = cpllreset_in;
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}: begin : gen_txqpll0_rxqpll1
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int}};
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_rx_int}};
              assign cpllreset_int  = cpllreset_in;
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:  begin : gen_txqpll0_rxcpll
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int}};
              assign qpll1reset_int = qpll1reset_in;
              assign cpllreset_int  = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_rx_int}};
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}: begin : gen_txqpll1_rxqpll0
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_rx_int}};
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int}};
              assign cpllreset_int  = cpllreset_in;
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}: begin : gen_txqpll1_rxqpll1
              assign qpll0reset_int = qpll0reset_in;
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int || gtwiz_reset_pllreset_rx_int}};
              assign cpllreset_int  = cpllreset_in;
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:  begin : gen_txqpll1_rxcpll
              assign qpll0reset_int = qpll0reset_in;
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int}};
              assign cpllreset_int  = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_rx_int}};
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}: begin : gen_txcpll_rxqpll0
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_rx_int}};
              assign qpll1reset_int = qpll1reset_in;
              assign cpllreset_int  = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_tx_int}};
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}: begin : gen_txcpll_rxqpll1
              assign qpll0reset_int = qpll0reset_in;
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_rx_int}};
              assign cpllreset_int  = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_tx_int}};
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:  begin : gen_txcpll_rxcpll
              assign qpll0reset_int = qpll0reset_in;
              assign qpll1reset_int = qpll1reset_in;
              assign cpllreset_int  = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_tx_int || gtwiz_reset_pllreset_rx_int}};
            end
          endcase
          assign cpllpd_int  = cpllpd_in;
        end
        else begin : gen_rst_assign_prod
          case ({C_TX_PLL_TYPE, C_RX_PLL_TYPE})
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}: begin : gen_txqpll0_rxqpll0
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int || gtwiz_reset_pllreset_rx_int}};
              assign qpll1reset_int = qpll1reset_in;
              assign cpllpd_int     = cpllpd_in;
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}: begin : gen_txqpll0_rxqpll1
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int}};
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_rx_int}};
              assign cpllpd_int     = cpllpd_in;
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:  begin : gen_txqpll0_rxcpll
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int}};
              assign qpll1reset_int = qpll1reset_in;
              assign cpllpd_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_rx_int}};
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}: begin : gen_txqpll1_rxqpll0
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_rx_int}};
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int}};
              assign cpllpd_int     = cpllpd_in;
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}: begin : gen_txqpll1_rxqpll1
              assign qpll0reset_int = qpll0reset_in;
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int || gtwiz_reset_pllreset_rx_int}};
              assign cpllpd_int     = cpllpd_in;
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:  begin : gen_txqpll1_rxcpll
              assign qpll0reset_int = qpll0reset_in;
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_tx_int}};
              assign cpllpd_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_rx_int}};
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}: begin : gen_txcpll_rxqpll0
              assign qpll0reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_rx_int}};
              assign qpll1reset_int = qpll1reset_in;
              assign cpllpd_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_tx_int}};
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}: begin : gen_txcpll_rxqpll1
              assign qpll0reset_int = qpll0reset_in;
              assign qpll1reset_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM{gtwiz_reset_pllreset_rx_int}};
              assign cpllpd_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_tx_int}};
            end

            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:  begin : gen_txcpll_rxcpll
              assign qpll0reset_int = qpll0reset_in;
              assign qpll1reset_int = qpll1reset_in;
              assign cpllpd_int     = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_pllreset_tx_int || gtwiz_reset_pllreset_rx_int}};
            end
          endcase
          assign cpllreset_int  = cpllreset_in;
        end

        // Fan out appropriate reset controller outputs to all transceiver channels
        assign txprogdivreset_int  = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_txprogdivreset_int}};
        assign gttxreset_int       = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_gttxreset_int}};
        assign txuserrdy_int       = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_txuserrdy_int}};
        assign rxprogdivreset_int  = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_rxprogdivreset_int}};
        assign gtrxreset_int       = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_gtrxreset_int}};
        assign rxuserrdy_int       = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_reset_rxuserrdy_int}};

      end

      // Generate one module instance per channel, each of which is used to control only that channel and its PLL(s)
      else if (C_RESET_CONTROLLER_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__PER_CHANNEL)
      begin : gen_per_channel_instance

        // Depending on the number of user clocking network helper blocks, either use the single user clock active
        // indicator or per-channel user clock active indicators as the user clock active indicators for use in the
        // per-channel instances of this block
        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] gtwiz_reset_userclk_tx_active_int;
        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] gtwiz_reset_userclk_rx_active_int;

        if (C_TX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE)
        begin : gen_txuserclkactive_single_instance
          assign gtwiz_reset_userclk_tx_active_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_userclk_tx_active_out}};
        end
        else begin : gen_txuserclkactive_per_channel_instance
          assign gtwiz_reset_userclk_tx_active_int = gtwiz_userclk_tx_active_out;
        end
        if (C_RX_USER_CLOCKING_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_USER_CLOCKING_INSTANCE_CTRL__SINGLE_INSTANCE)
        begin : gen_rxuserclkactive_single_instance
          assign gtwiz_reset_userclk_rx_active_int = {`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH{gtwiz_userclk_rx_active_out}};
        end
        else begin : gen_rxuserclkactive_per_channel_instance
          assign gtwiz_reset_userclk_rx_active_int = gtwiz_userclk_rx_active_out;
        end

        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] gtwiz_reset_plllock_tx_int;
        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] gtwiz_reset_plllock_rx_int;
        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] gtwiz_reset_pllreset_tx_int;
        wire [`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH-1:0] gtwiz_reset_pllreset_rx_int;

        // Assign tie-off values for use in reset controller state machine traversal
        wire gtwiz_reset_tx_enabled_tie_int;
        wire gtwiz_reset_rx_enabled_tie_int;
        wire gtwiz_reset_shared_pll_tie_int;

        if (C_TX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_ENABLE__ENABLED)
        begin : gen_reset_tx_enabled_tie_high
          assign gtwiz_reset_tx_enabled_tie_int = 1'b1;
        end
        else begin : gen_reset_tx_enabled_tie_low
          assign gtwiz_reset_tx_enabled_tie_int = 1'b0;
        end

        if (C_RX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_ENABLE__ENABLED)
        begin : gen_reset_rx_enabled_tie_high
          assign gtwiz_reset_rx_enabled_tie_int = 1'b1;
        end
        else begin : gen_reset_rx_enabled_tie_low
          assign gtwiz_reset_rx_enabled_tie_int = 1'b0;
        end

        if (C_TX_PLL_TYPE == C_RX_PLL_TYPE)
        begin : gen_reset_shared_pll_tie_high
          assign gtwiz_reset_shared_pll_tie_int = 1'b1;
        end
        else begin : gen_reset_shared_pll_tie_low
          assign gtwiz_reset_shared_pll_tie_int = 1'b0;
        end

        genvar gi_hb_rst_ch;
        for (gi_hb_rst_ch = 0; gi_hb_rst_ch < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH; gi_hb_rst_ch = gi_hb_rst_ch + 1) begin : gen_channel_container

          // For each data direction of each channel, select the appropriate PLL lock signal such that the reset
          // controller can sense when that channel's PLL is locked (or PLLs are locked)
          case (C_TX_PLL_TYPE)
            `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0:
              assign gtwiz_reset_plllock_tx_int[gi_hb_rst_ch] = qpll0lock_int[f_idx_cm(gi_hb_rst_ch)];
            `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1:
              assign gtwiz_reset_plllock_tx_int[gi_hb_rst_ch] = qpll1lock_int[f_idx_cm(gi_hb_rst_ch)];
            `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL:
              assign gtwiz_reset_plllock_tx_int[gi_hb_rst_ch] = cplllock_int[gi_hb_rst_ch];
          endcase
          case (C_RX_PLL_TYPE)
            `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0:
              assign gtwiz_reset_plllock_rx_int[gi_hb_rst_ch] = qpll0lock_int[f_idx_cm(gi_hb_rst_ch)];
            `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1:
              assign gtwiz_reset_plllock_rx_int[gi_hb_rst_ch] = qpll1lock_int[f_idx_cm(gi_hb_rst_ch)];
            `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL:
              assign gtwiz_reset_plllock_rx_int[gi_hb_rst_ch] = cplllock_int[gi_hb_rst_ch];
          endcase

          // Instantiate a reset controller per channel
          gtwizard_ultrascale_v1_6_2_gtwiz_reset #(
            .P_FREERUN_FREQUENCY       (C_FREERUN_FREQUENCY),
            .P_USE_CPLL_CAL            (P_USE_CPLL_CAL),
            .P_TX_PLL_TYPE             (C_TX_PLL_TYPE),
            .P_RX_PLL_TYPE             (C_RX_PLL_TYPE),
            .P_RX_LINE_RATE            (C_RX_LINE_RATE),
            .P_CDR_TIMEOUT_FREERUN_CYC (P_CDR_TIMEOUT_FREERUN_CYC)
          ) gtwiz_reset_inst (
            .gtwiz_reset_clk_freerun_in         (gtwiz_reset_clk_freerun_in         [gi_hb_rst_ch]),
            .gtwiz_reset_all_in                 (gtwiz_reset_all_in                 [gi_hb_rst_ch]),
            .gtwiz_reset_tx_pll_and_datapath_in (gtwiz_reset_tx_pll_and_datapath_in [gi_hb_rst_ch]),
            .gtwiz_reset_tx_datapath_in         (gtwiz_reset_tx_datapath_in         [gi_hb_rst_ch]),
            .gtwiz_reset_rx_pll_and_datapath_in (gtwiz_reset_rx_pll_and_datapath_in [gi_hb_rst_ch]),
            .gtwiz_reset_rx_datapath_in         (gtwiz_reset_rx_datapath_in         [gi_hb_rst_ch]),
            .gtwiz_reset_rx_cdr_stable_out      (gtwiz_reset_rx_cdr_stable_out      [gi_hb_rst_ch]),
            .gtwiz_reset_tx_done_out            (gtwiz_reset_tx_done_out            [gi_hb_rst_ch]),
            .gtwiz_reset_rx_done_out            (gtwiz_reset_rx_done_out            [gi_hb_rst_ch]),
            .gtwiz_reset_userclk_tx_active_in   (gtwiz_reset_userclk_tx_active_int  [gi_hb_rst_ch]),
            .gtwiz_reset_userclk_rx_active_in   (gtwiz_reset_userclk_rx_active_int  [gi_hb_rst_ch]),
            .gtpowergood_in                     (gtpowergood_int                    [gi_hb_rst_ch]),
            .txusrclk2_in                       (txusrclk2_int                      [gi_hb_rst_ch]),
            .plllock_tx_in                      (gtwiz_reset_plllock_tx_int         [gi_hb_rst_ch]),
            .txresetdone_in                     (txresetdone_int                    [gi_hb_rst_ch]),
            .rxusrclk2_in                       (rxusrclk2_int                      [gi_hb_rst_ch]),
            .plllock_rx_in                      (gtwiz_reset_plllock_rx_int         [gi_hb_rst_ch]),
            .rxcdrlock_in                       (rxcdrlock_int                      [gi_hb_rst_ch]),
            .rxresetdone_in                     (rxresetdone_int                    [gi_hb_rst_ch]),
            .pllreset_tx_out                    (gtwiz_reset_pllreset_tx_int        [gi_hb_rst_ch]),
            .txprogdivreset_out                 (txprogdivreset_int                 [gi_hb_rst_ch]),
            .gttxreset_out                      (gttxreset_int                      [gi_hb_rst_ch]),
            .txuserrdy_out                      (txuserrdy_int                      [gi_hb_rst_ch]),
            .pllreset_rx_out                    (gtwiz_reset_pllreset_rx_int        [gi_hb_rst_ch]),
            .rxprogdivreset_out                 (rxprogdivreset_int                 [gi_hb_rst_ch]),
            .gtrxreset_out                      (gtrxreset_int                      [gi_hb_rst_ch]),
            .rxuserrdy_out                      (rxuserrdy_int                      [gi_hb_rst_ch]),
            .tx_enabled_tie_in                  (gtwiz_reset_tx_enabled_tie_int),
            .rx_enabled_tie_in                  (gtwiz_reset_rx_enabled_tie_int),
            .shared_pll_tie_in                  (gtwiz_reset_shared_pll_tie_int)
          );

          // If the core is configured to use the CPLL for either the transmit or the receive data direction, drive the
          // CPLL reset input with the appropriate PLL reset signals from by the reset controller, for each channel.
          if ((C_GT_REV == 11) || (C_GT_REV == 12) || (C_GT_REV == 14) || (C_GT_REV == 16)) begin : gen_cpllreset_assign_es
            case ({C_TX_PLL_TYPE, C_RX_PLL_TYPE})
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}:
                assign cpllreset_int[gi_hb_rst_ch] = cpllreset_in[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}:
                assign cpllreset_int[gi_hb_rst_ch] = cpllreset_in[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:
                assign cpllreset_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_rx_int[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}:
                assign cpllreset_int[gi_hb_rst_ch] = cpllreset_in[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}:
                assign cpllreset_int[gi_hb_rst_ch] = cpllreset_in[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:
                assign cpllreset_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_rx_int[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}:
                assign cpllreset_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_tx_int[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}:
                assign cpllreset_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_tx_int[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:
                assign cpllreset_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_tx_int[gi_hb_rst_ch] ||
                                                     gtwiz_reset_pllreset_rx_int[gi_hb_rst_ch];
            endcase
            assign cpllpd_int[gi_hb_rst_ch] = cpllpd_in[gi_hb_rst_ch];
          end
          else begin : gen_cpllreset_assign_prod
            case ({C_TX_PLL_TYPE, C_RX_PLL_TYPE})
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}:
                assign cpllpd_int[gi_hb_rst_ch] = cpllpd_in[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}:
                assign cpllpd_int[gi_hb_rst_ch] = cpllpd_in[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:
                assign cpllpd_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_rx_int[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}:
                assign cpllpd_int[gi_hb_rst_ch] = cpllpd_in[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}:
                assign cpllpd_int[gi_hb_rst_ch] = cpllpd_in[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:
                assign cpllpd_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_rx_int[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}:
                assign cpllpd_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_tx_int[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}:
                assign cpllpd_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_tx_int[gi_hb_rst_ch];
              {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:
                assign cpllpd_int[gi_hb_rst_ch] = gtwiz_reset_pllreset_tx_int[gi_hb_rst_ch] ||
                                                  gtwiz_reset_pllreset_rx_int[gi_hb_rst_ch];
            endcase
            assign cpllreset_int[gi_hb_rst_ch] = cpllreset_in[gi_hb_rst_ch];
          end
        end

        // If the core is configured to use a QPLL for either the transmit or the receive data direction, drive the
        // QPLL reset inputs with the appropriate PLL reset signals from by the reset controller, for each channel.
        // Because a single QPLL may be shared by multiple channels, and therefore multiple reset controllers in this
        // configuration, combine the relevant reset controllers' signals to drive each QPLL reset signal.
        genvar gi_hb_rst_cm;
        for (gi_hb_rst_cm = 0; gi_hb_rst_cm < `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_SF_CM; gi_hb_rst_cm = gi_hb_rst_cm + 1) begin : gen_common_container

          case ({C_TX_PLL_TYPE, C_RX_PLL_TYPE})
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}: begin : gen_txqpll0_rxqpll0
              assign qpll0reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_tx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]) ||
                     (|gtwiz_reset_pllreset_rx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
              assign qpll1reset_int[gi_hb_rst_cm] = qpll1reset_in[gi_hb_rst_cm];
            end
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}: begin : gen_txqpll0_rxqpll1
              assign qpll0reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_tx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
              assign qpll1reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_rx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
            end
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL0, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:  begin : gen_txqpll0_rxcpll
              assign qpll0reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_tx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
              assign qpll1reset_int[gi_hb_rst_cm] = qpll1reset_in[gi_hb_rst_cm];
            end
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}: begin : gen_txqpll1_rxqpll0
              assign qpll0reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_rx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
              assign qpll1reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_tx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
            end
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}: begin : gen_txqpll1_rxqpll1
              assign qpll0reset_int[gi_hb_rst_cm] = qpll0reset_in[gi_hb_rst_cm];
              assign qpll1reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_tx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]) ||
                     (|gtwiz_reset_pllreset_rx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
            end
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__QPLL1, 32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:  begin : gen_txqpll1_rxcpll
              assign qpll0reset_int[gi_hb_rst_cm] = qpll0reset_in[gi_hb_rst_cm];
              assign qpll1reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_tx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
            end
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL0}: begin : gen_txcpll_rxqpll0
              assign qpll0reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_rx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
              assign qpll1reset_int[gi_hb_rst_cm] = qpll1reset_in[gi_hb_rst_cm];
            end
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__QPLL1}: begin : gen_txcpll_rxqpll1
              assign qpll0reset_int[gi_hb_rst_cm] = qpll0reset_in[gi_hb_rst_cm];
              assign qpll1reset_int[gi_hb_rst_cm] =
                     (|gtwiz_reset_pllreset_rx_int[f_idx_ch_ub(gi_hb_rst_cm):f_idx_ch_lb(gi_hb_rst_cm)]);
            end
            {32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_PLL_TYPE__CPLL,  32'd`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_PLL_TYPE__CPLL}:  begin : gen_txcpll_rxcpll
              assign qpll0reset_int[gi_hb_rst_cm] = qpll0reset_in[gi_hb_rst_cm];
              assign qpll1reset_int[gi_hb_rst_cm] = qpll1reset_in[gi_hb_rst_cm];
            end
          endcase

        end

      end
    end

    // Do not include the helper block within the core
    else begin : gen_reset_controller_external

      if (C_RESET_CONTROLLER_INSTANCE_CTRL == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RESET_CONTROLLER_INSTANCE_CTRL__SINGLE_INSTANCE)
      begin : gen_single_instance
        assign gtwiz_reset_rx_cdr_stable_out = 1'b0;
      end
      else begin : gen_per_channel_instance
        assign gtwiz_reset_rx_cdr_stable_out = {(C_RESET_CONTROLLER_INSTANCE_CTRL*`GigEthGthUltraScaleCore_gt_gtwizard_gthe3_N_CH){1'b0}};
      end

      assign gtwiz_reset_tx_done_out = gtwiz_reset_tx_done_in;
      assign gtwiz_reset_rx_done_out = gtwiz_reset_rx_done_in;
      assign qpll0reset_int          = qpll0reset_in;
      assign qpll1reset_int          = qpll1reset_in;
      assign cpllreset_int           = cpllreset_in;
      assign cpllpd_int              = cpllpd_in;
      assign txprogdivreset_int      = txprogdivreset_in;
      assign gttxreset_int           = gttxreset_in;
      assign txuserrdy_int           = txuserrdy_in;
      assign rxprogdivreset_int      = rxprogdivreset_in;
      assign gtrxreset_int           = gtrxreset_in;
      assign rxuserrdy_int           = rxuserrdy_in;

    end

    // Assign QPLL reset outputs to corresponding reset controller signals for use in the case where the common block
    // is not within the core
    assign gtwiz_reset_qpll0reset_out = qpll0reset_int;
    assign gtwiz_reset_qpll1reset_out = qpll1reset_int;


    // ----------------------------------------------------------------------------------------------------------------
    // Transmitter user data width sizing helper block
    // ----------------------------------------------------------------------------------------------------------------

    // Include the helper block within the core
    if ((C_TX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_ENABLE__ENABLED) &&
        (C_LOCATE_USER_DATA_WIDTH_SIZING == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_USER_DATA_WIDTH_SIZING__CORE))
        begin : gen_tx_userdata_internal

      // Declare vectors for the helper block to drive transceiver-facing TXDATA, TXCTRL0, and TXCTRL1 ports
      wire [(C_TOTAL_NUM_CHANNELS*128)-1:0] gtwiz_userdata_tx_txdata_int;
      wire [(C_TOTAL_NUM_CHANNELS* 16)-1:0] gtwiz_userdata_tx_txctrl0_int;
      wire [(C_TOTAL_NUM_CHANNELS* 16)-1:0] gtwiz_userdata_tx_txctrl1_int;

      gtwizard_ultrascale_v1_6_2_gtwiz_userdata_tx #(
        .P_TX_USER_DATA_WIDTH       (C_TX_USER_DATA_WIDTH),
        .P_TX_DATA_ENCODING         (C_TX_DATA_ENCODING),
        .P_TOTAL_NUMBER_OF_CHANNELS (C_TOTAL_NUM_CHANNELS)
      ) gtwiz_userdata_tx_inst (
        .gtwiz_userdata_tx_in (gtwiz_userdata_tx_in),
        .txdata_out           (gtwiz_userdata_tx_txdata_int),
        .txctrl0_out          (gtwiz_userdata_tx_txctrl0_int),
        .txctrl1_out          (gtwiz_userdata_tx_txctrl1_int)
      );

      // The txdata_int vector is always driven by the helper block when it is present
      assign txdata_int = gtwiz_userdata_tx_txdata_int;

      // The txctrl0_int and txctrl1_int vectors are driven by the helper block only when transmitter data decoding is
      // raw and user data width is modulus 10; otherwise, they are driven by corresponding inputs
      if ((C_TX_DATA_ENCODING == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_TX_DATA_ENCODING__RAW) &&
          (C_TX_USER_DATA_WIDTH % 10 == 0))
          begin : gen_tx_ctrl_internal
        assign txctrl0_int = gtwiz_userdata_tx_txctrl0_int;
        assign txctrl1_int = gtwiz_userdata_tx_txctrl1_int;
      end
      else begin : gen_tx_ctrl_external
        assign txctrl0_int = txctrl0_in;
        assign txctrl1_int = txctrl1_in;
      end

    end

    // Do not include the helper block within the core
    else begin : gen_no_tx_userdata_internal
      assign txdata_int  = txdata_in;
      assign txctrl0_int = txctrl0_in;
      assign txctrl1_int = txctrl1_in;
    end


    // ----------------------------------------------------------------------------------------------------------------
    // Receiver user data width sizing helper block
    // ----------------------------------------------------------------------------------------------------------------

    // Include the helper block within the core
    if ((C_RX_ENABLE == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_RX_ENABLE__ENABLED) &&
        (C_LOCATE_USER_DATA_WIDTH_SIZING == `GigEthGthUltraScaleCore_gt_gtwizard_gthe3_LOCATE_USER_DATA_WIDTH_SIZING__CORE))
        begin : gen_rx_userdata_internal

      gtwizard_ultrascale_v1_6_2_gtwiz_userdata_rx #(
        .P_RX_USER_DATA_WIDTH       (C_RX_USER_DATA_WIDTH),
        .P_RX_DATA_DECODING         (C_RX_DATA_DECODING),
        .P_TOTAL_NUMBER_OF_CHANNELS (C_TOTAL_NUM_CHANNELS)
      ) gtwiz_userdata_rx_inst (
        .rxdata_in             (rxdata_int),
        .rxctrl0_in            (rxctrl0_int),
        .rxctrl1_in            (rxctrl1_int),
        .gtwiz_userdata_rx_out (gtwiz_userdata_rx_out)
      );
    end

    // Do not include the helper block within the core
    else begin : gen_no_rx_userdata_internal
      assign gtwiz_userdata_rx_out = {C_TOTAL_NUM_CHANNELS*C_RX_USER_DATA_WIDTH{1'b0}};
    end

  end
  endgenerate


endmodule

