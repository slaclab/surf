//------------------------------------------------------------------------------
//  (c) Copyright 2013-2014 Xilinx, Inc. All rights reserved.
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

module gtwizard_ultrascale_v1_4_gthe3_common #(


  // -------------------------------------------------------------------------------------------------------------------
  // Parameters relating to GTHE3_COMMON primitive
  // -------------------------------------------------------------------------------------------------------------------

  // primitive wrapper parameters which override corresponding GTHE3_COMMON primitive parameters
  parameter  [15:0] GTHE3_COMMON_BIAS_CFG0 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_BIAS_CFG1 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_BIAS_CFG2 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_BIAS_CFG3 = 16'h0040,
  parameter  [15:0] GTHE3_COMMON_BIAS_CFG4 = 16'h0000,
  parameter   [9:0] GTHE3_COMMON_BIAS_CFG_RSVD = 10'b0000000000,
  parameter  [15:0] GTHE3_COMMON_COMMON_CFG0 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_COMMON_CFG1 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_POR_CFG = 16'h0004,
  parameter  [15:0] GTHE3_COMMON_QPLL0_CFG0 = 16'h3018,
  parameter  [15:0] GTHE3_COMMON_QPLL0_CFG1 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_QPLL0_CFG1_G3 = 16'h0020,
  parameter  [15:0] GTHE3_COMMON_QPLL0_CFG2 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_QPLL0_CFG2_G3 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_QPLL0_CFG3 = 16'h0120,
  parameter  [15:0] GTHE3_COMMON_QPLL0_CFG4 = 16'h0009,
  parameter   [9:0] GTHE3_COMMON_QPLL0_CP = 10'b0000011111,
  parameter   [9:0] GTHE3_COMMON_QPLL0_CP_G3 = 10'b0000011111,
  parameter integer GTHE3_COMMON_QPLL0_FBDIV = 66,
  parameter integer GTHE3_COMMON_QPLL0_FBDIV_G3 = 80,
  parameter  [15:0] GTHE3_COMMON_QPLL0_INIT_CFG0 = 16'h0000,
  parameter   [7:0] GTHE3_COMMON_QPLL0_INIT_CFG1 = 8'h00,
  parameter  [15:0] GTHE3_COMMON_QPLL0_LOCK_CFG = 16'h01E8,
  parameter  [15:0] GTHE3_COMMON_QPLL0_LOCK_CFG_G3 = 16'h01E8,
  parameter   [9:0] GTHE3_COMMON_QPLL0_LPF = 10'b1111111111,
  parameter   [9:0] GTHE3_COMMON_QPLL0_LPF_G3 = 10'b1111111111,
  parameter integer GTHE3_COMMON_QPLL0_REFCLK_DIV = 2,
  parameter  [15:0] GTHE3_COMMON_QPLL0_SDM_CFG0 = 16'b0000000001000000,
  parameter  [15:0] GTHE3_COMMON_QPLL0_SDM_CFG1 = 16'b0000000000000000,
  parameter  [15:0] GTHE3_COMMON_QPLL0_SDM_CFG2 = 16'b0000000000000000,
  parameter  [15:0] GTHE3_COMMON_QPLL1_CFG0 = 16'h3018,
  parameter  [15:0] GTHE3_COMMON_QPLL1_CFG1 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_QPLL1_CFG1_G3 = 16'h0020,
  parameter  [15:0] GTHE3_COMMON_QPLL1_CFG2 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_QPLL1_CFG2_G3 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_QPLL1_CFG3 = 16'h0120,
  parameter  [15:0] GTHE3_COMMON_QPLL1_CFG4 = 16'h0009,
  parameter   [9:0] GTHE3_COMMON_QPLL1_CP = 10'b0000011111,
  parameter   [9:0] GTHE3_COMMON_QPLL1_CP_G3 = 10'b0000011111,
  parameter integer GTHE3_COMMON_QPLL1_FBDIV = 66,
  parameter integer GTHE3_COMMON_QPLL1_FBDIV_G3 = 80,
  parameter  [15:0] GTHE3_COMMON_QPLL1_INIT_CFG0 = 16'h0000,
  parameter   [7:0] GTHE3_COMMON_QPLL1_INIT_CFG1 = 8'h00,
  parameter  [15:0] GTHE3_COMMON_QPLL1_LOCK_CFG = 16'h01E8,
  parameter  [15:0] GTHE3_COMMON_QPLL1_LOCK_CFG_G3 = 16'h21E8,
  parameter   [9:0] GTHE3_COMMON_QPLL1_LPF = 10'b1111111111,
  parameter   [9:0] GTHE3_COMMON_QPLL1_LPF_G3 = 10'b1111111111,
  parameter integer GTHE3_COMMON_QPLL1_REFCLK_DIV = 2,
  parameter  [15:0] GTHE3_COMMON_QPLL1_SDM_CFG0 = 16'b0000000001000000,
  parameter  [15:0] GTHE3_COMMON_QPLL1_SDM_CFG1 = 16'b0000000000000000,
  parameter  [15:0] GTHE3_COMMON_QPLL1_SDM_CFG2 = 16'b0000000000000000,
  parameter  [15:0] GTHE3_COMMON_RSVD_ATTR0 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_RSVD_ATTR1 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_RSVD_ATTR2 = 16'h0000,
  parameter  [15:0] GTHE3_COMMON_RSVD_ATTR3 = 16'h0000,
  parameter   [1:0] GTHE3_COMMON_RXRECCLKOUT0_SEL = 2'b00,
  parameter   [1:0] GTHE3_COMMON_RXRECCLKOUT1_SEL = 2'b00,
  parameter   [0:0] GTHE3_COMMON_SARC_EN = 1'b1,
  parameter   [0:0] GTHE3_COMMON_SARC_SEL = 1'b0,
  parameter  [15:0] GTHE3_COMMON_SDM0DATA1_0 = 16'b0000000000000000,
  parameter   [8:0] GTHE3_COMMON_SDM0DATA1_1 = 9'b000000000,
  parameter  [15:0] GTHE3_COMMON_SDM0INITSEED0_0 = 16'b0000000000000000,
  parameter   [8:0] GTHE3_COMMON_SDM0INITSEED0_1 = 9'b000000000,
  parameter   [0:0] GTHE3_COMMON_SDM0_DATA_PIN_SEL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_SDM0_WIDTH_PIN_SEL = 1'b0,
  parameter  [15:0] GTHE3_COMMON_SDM1DATA1_0 = 16'b0000000000000000,
  parameter   [8:0] GTHE3_COMMON_SDM1DATA1_1 = 9'b000000000,
  parameter  [15:0] GTHE3_COMMON_SDM1INITSEED0_0 = 16'b0000000000000000,
  parameter   [8:0] GTHE3_COMMON_SDM1INITSEED0_1 = 9'b000000000,
  parameter   [0:0] GTHE3_COMMON_SDM1_DATA_PIN_SEL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_SDM1_WIDTH_PIN_SEL = 1'b0,
  parameter         GTHE3_COMMON_SIM_RESET_SPEEDUP = "TRUE",
  parameter integer GTHE3_COMMON_SIM_VERSION = 2,

  // primitive wrapper parameters which specify GTHE3_COMMON primitive input port default driver values
  parameter   [0:0] GTHE3_COMMON_BGBYPASSB_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_BGMONITORENB_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_BGPDB_VAL = 1'b0,
  parameter   [4:0] GTHE3_COMMON_BGRCALOVRD_VAL = 5'b0,
  parameter   [0:0] GTHE3_COMMON_BGRCALOVRDENB_VAL = 1'b0,
  parameter   [8:0] GTHE3_COMMON_DRPADDR_VAL = 9'b0,
  parameter   [0:0] GTHE3_COMMON_DRPCLK_VAL = 1'b0,
  parameter  [15:0] GTHE3_COMMON_DRPDI_VAL = 16'b0,
  parameter   [0:0] GTHE3_COMMON_DRPEN_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_DRPWE_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTGREFCLK0_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTGREFCLK1_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTNORTHREFCLK00_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTNORTHREFCLK01_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTNORTHREFCLK10_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTNORTHREFCLK11_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTREFCLK00_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTREFCLK01_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTREFCLK10_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTREFCLK11_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTSOUTHREFCLK00_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTSOUTHREFCLK01_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTSOUTHREFCLK10_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTSOUTHREFCLK11_VAL = 1'b0,
  parameter   [7:0] GTHE3_COMMON_PMARSVD0_VAL = 8'b0,
  parameter   [7:0] GTHE3_COMMON_PMARSVD1_VAL = 8'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0CLKRSVD0_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0CLKRSVD1_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0LOCKDETCLK_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0LOCKEN_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0PD_VAL = 1'b0,
  parameter   [2:0] GTHE3_COMMON_QPLL0REFCLKSEL_VAL = 3'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0RESET_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1CLKRSVD0_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1CLKRSVD1_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1LOCKDETCLK_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1LOCKEN_VAL = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1PD_VAL = 1'b0,
  parameter   [2:0] GTHE3_COMMON_QPLL1REFCLKSEL_VAL = 3'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1RESET_VAL = 1'b0,
  parameter   [7:0] GTHE3_COMMON_QPLLRSVD1_VAL = 8'b0,
  parameter   [4:0] GTHE3_COMMON_QPLLRSVD2_VAL = 5'b0,
  parameter   [4:0] GTHE3_COMMON_QPLLRSVD3_VAL = 5'b0,
  parameter   [7:0] GTHE3_COMMON_QPLLRSVD4_VAL = 8'b0,
  parameter   [0:0] GTHE3_COMMON_RCALENB_VAL = 1'b0,

  // primitive wrapper parameters which control GTHE3_COMMON primitive input port tie-off enablement
  parameter   [0:0] GTHE3_COMMON_BGBYPASSB_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_BGMONITORENB_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_BGPDB_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_BGRCALOVRD_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_BGRCALOVRDENB_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_DRPADDR_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_DRPCLK_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_DRPDI_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_DRPEN_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_DRPWE_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTGREFCLK0_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTGREFCLK1_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTNORTHREFCLK00_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTNORTHREFCLK01_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTNORTHREFCLK10_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTNORTHREFCLK11_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTREFCLK00_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTREFCLK01_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTREFCLK10_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTREFCLK11_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTSOUTHREFCLK00_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTSOUTHREFCLK01_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTSOUTHREFCLK10_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_GTSOUTHREFCLK11_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_PMARSVD0_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_PMARSVD1_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0CLKRSVD0_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0CLKRSVD1_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0LOCKDETCLK_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0LOCKEN_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0PD_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0REFCLKSEL_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL0RESET_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1CLKRSVD0_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1CLKRSVD1_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1LOCKDETCLK_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1LOCKEN_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1PD_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1REFCLKSEL_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLL1RESET_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLLRSVD1_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLLRSVD2_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLLRSVD3_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_QPLLRSVD4_TIE_EN = 1'b0,
  parameter   [0:0] GTHE3_COMMON_RCALENB_TIE_EN = 1'b0

)(


  // -------------------------------------------------------------------------------------------------------------------
  // Ports relating to GTHE3_COMMON primitive
  // -------------------------------------------------------------------------------------------------------------------

  // primitive wrapper input ports which can drive corresponding GTHE3_COMMON primitive input ports
  input  wire [ 0:0] GTHE3_COMMON_BGBYPASSB,
  input  wire [ 0:0] GTHE3_COMMON_BGMONITORENB,
  input  wire [ 0:0] GTHE3_COMMON_BGPDB,
  input  wire [ 4:0] GTHE3_COMMON_BGRCALOVRD,
  input  wire [ 0:0] GTHE3_COMMON_BGRCALOVRDENB,
  input  wire [ 8:0] GTHE3_COMMON_DRPADDR,
  input  wire [ 0:0] GTHE3_COMMON_DRPCLK,
  input  wire [15:0] GTHE3_COMMON_DRPDI,
  input  wire [ 0:0] GTHE3_COMMON_DRPEN,
  input  wire [ 0:0] GTHE3_COMMON_DRPWE,
  input  wire [ 0:0] GTHE3_COMMON_GTGREFCLK0,
  input  wire [ 0:0] GTHE3_COMMON_GTGREFCLK1,
  input  wire [ 0:0] GTHE3_COMMON_GTNORTHREFCLK00,
  input  wire [ 0:0] GTHE3_COMMON_GTNORTHREFCLK01,
  input  wire [ 0:0] GTHE3_COMMON_GTNORTHREFCLK10,
  input  wire [ 0:0] GTHE3_COMMON_GTNORTHREFCLK11,
  input  wire [ 0:0] GTHE3_COMMON_GTREFCLK00,
  input  wire [ 0:0] GTHE3_COMMON_GTREFCLK01,
  input  wire [ 0:0] GTHE3_COMMON_GTREFCLK10,
  input  wire [ 0:0] GTHE3_COMMON_GTREFCLK11,
  input  wire [ 0:0] GTHE3_COMMON_GTSOUTHREFCLK00,
  input  wire [ 0:0] GTHE3_COMMON_GTSOUTHREFCLK01,
  input  wire [ 0:0] GTHE3_COMMON_GTSOUTHREFCLK10,
  input  wire [ 0:0] GTHE3_COMMON_GTSOUTHREFCLK11,
  input  wire [ 7:0] GTHE3_COMMON_PMARSVD0,
  input  wire [ 7:0] GTHE3_COMMON_PMARSVD1,
  input  wire [ 0:0] GTHE3_COMMON_QPLL0CLKRSVD0,
  input  wire [ 0:0] GTHE3_COMMON_QPLL0CLKRSVD1,
  input  wire [ 0:0] GTHE3_COMMON_QPLL0LOCKDETCLK,
  input  wire [ 0:0] GTHE3_COMMON_QPLL0LOCKEN,
  input  wire [ 0:0] GTHE3_COMMON_QPLL0PD,
  input  wire [ 2:0] GTHE3_COMMON_QPLL0REFCLKSEL,
  input  wire [ 0:0] GTHE3_COMMON_QPLL0RESET,
  input  wire [ 0:0] GTHE3_COMMON_QPLL1CLKRSVD0,
  input  wire [ 0:0] GTHE3_COMMON_QPLL1CLKRSVD1,
  input  wire [ 0:0] GTHE3_COMMON_QPLL1LOCKDETCLK,
  input  wire [ 0:0] GTHE3_COMMON_QPLL1LOCKEN,
  input  wire [ 0:0] GTHE3_COMMON_QPLL1PD,
  input  wire [ 2:0] GTHE3_COMMON_QPLL1REFCLKSEL,
  input  wire [ 0:0] GTHE3_COMMON_QPLL1RESET,
  input  wire [ 7:0] GTHE3_COMMON_QPLLRSVD1,
  input  wire [ 4:0] GTHE3_COMMON_QPLLRSVD2,
  input  wire [ 4:0] GTHE3_COMMON_QPLLRSVD3,
  input  wire [ 7:0] GTHE3_COMMON_QPLLRSVD4,
  input  wire [ 0:0] GTHE3_COMMON_RCALENB,

  // primitive wrapper output ports which are driven by corresponding GTHE3_COMMON primitive output ports
  output wire [15:0] GTHE3_COMMON_DRPDO,
  output wire [ 0:0] GTHE3_COMMON_DRPRDY,
  output wire [ 7:0] GTHE3_COMMON_PMARSVDOUT0,
  output wire [ 7:0] GTHE3_COMMON_PMARSVDOUT1,
  output wire [ 0:0] GTHE3_COMMON_QPLL0FBCLKLOST,
  output wire [ 0:0] GTHE3_COMMON_QPLL0LOCK,
  output wire [ 0:0] GTHE3_COMMON_QPLL0OUTCLK,
  output wire [ 0:0] GTHE3_COMMON_QPLL0OUTREFCLK,
  output wire [ 0:0] GTHE3_COMMON_QPLL0REFCLKLOST,
  output wire [ 0:0] GTHE3_COMMON_QPLL1FBCLKLOST,
  output wire [ 0:0] GTHE3_COMMON_QPLL1LOCK,
  output wire [ 0:0] GTHE3_COMMON_QPLL1OUTCLK,
  output wire [ 0:0] GTHE3_COMMON_QPLL1OUTREFCLK,
  output wire [ 0:0] GTHE3_COMMON_QPLL1REFCLKLOST,
  output wire [ 7:0] GTHE3_COMMON_QPLLDMONITOR0,
  output wire [ 7:0] GTHE3_COMMON_QPLLDMONITOR1,
  output wire [ 0:0] GTHE3_COMMON_REFCLKOUTMONITOR0,
  output wire [ 0:0] GTHE3_COMMON_REFCLKOUTMONITOR1,
  output wire [ 1:0] GTHE3_COMMON_RXRECCLK0_SEL,
  output wire [ 1:0] GTHE3_COMMON_RXRECCLK1_SEL

);


  // -------------------------------------------------------------------------------------------------------------------
  // HDL generation of wiring and instances relating to GTHE3_COMMON primitive
  // -------------------------------------------------------------------------------------------------------------------

  generate if (1) begin : gthe3_common_gen

    // for each GTHE3_COMMON primitive input port, declare a properly-sized vector
    wire [ 0:0] GTHE3_COMMON_BGBYPASSB_int;
    wire [ 0:0] GTHE3_COMMON_BGMONITORENB_int;
    wire [ 0:0] GTHE3_COMMON_BGPDB_int;
    wire [ 4:0] GTHE3_COMMON_BGRCALOVRD_int;
    wire [ 0:0] GTHE3_COMMON_BGRCALOVRDENB_int;
    wire [ 8:0] GTHE3_COMMON_DRPADDR_int;
    wire [ 0:0] GTHE3_COMMON_DRPCLK_int;
    wire [15:0] GTHE3_COMMON_DRPDI_int;
    wire [ 0:0] GTHE3_COMMON_DRPEN_int;
    wire [ 0:0] GTHE3_COMMON_DRPWE_int;
    wire [ 0:0] GTHE3_COMMON_GTGREFCLK0_int;
    wire [ 0:0] GTHE3_COMMON_GTGREFCLK1_int;
    wire [ 0:0] GTHE3_COMMON_GTNORTHREFCLK00_int;
    wire [ 0:0] GTHE3_COMMON_GTNORTHREFCLK01_int;
    wire [ 0:0] GTHE3_COMMON_GTNORTHREFCLK10_int;
    wire [ 0:0] GTHE3_COMMON_GTNORTHREFCLK11_int;
    wire [ 0:0] GTHE3_COMMON_GTREFCLK00_int;
    wire [ 0:0] GTHE3_COMMON_GTREFCLK01_int;
    wire [ 0:0] GTHE3_COMMON_GTREFCLK10_int;
    wire [ 0:0] GTHE3_COMMON_GTREFCLK11_int;
    wire [ 0:0] GTHE3_COMMON_GTSOUTHREFCLK00_int;
    wire [ 0:0] GTHE3_COMMON_GTSOUTHREFCLK01_int;
    wire [ 0:0] GTHE3_COMMON_GTSOUTHREFCLK10_int;
    wire [ 0:0] GTHE3_COMMON_GTSOUTHREFCLK11_int;
    wire [ 7:0] GTHE3_COMMON_PMARSVD0_int;
    wire [ 7:0] GTHE3_COMMON_PMARSVD1_int;
    wire [ 0:0] GTHE3_COMMON_QPLL0CLKRSVD0_int;
    wire [ 0:0] GTHE3_COMMON_QPLL0CLKRSVD1_int;
    wire [ 0:0] GTHE3_COMMON_QPLL0LOCKDETCLK_int;
    wire [ 0:0] GTHE3_COMMON_QPLL0LOCKEN_int;
    wire [ 0:0] GTHE3_COMMON_QPLL0PD_int;
    wire [ 2:0] GTHE3_COMMON_QPLL0REFCLKSEL_int;
    wire [ 0:0] GTHE3_COMMON_QPLL0RESET_int;
    wire [ 0:0] GTHE3_COMMON_QPLL1CLKRSVD0_int;
    wire [ 0:0] GTHE3_COMMON_QPLL1CLKRSVD1_int;
    wire [ 0:0] GTHE3_COMMON_QPLL1LOCKDETCLK_int;
    wire [ 0:0] GTHE3_COMMON_QPLL1LOCKEN_int;
    wire [ 0:0] GTHE3_COMMON_QPLL1PD_int;
    wire [ 2:0] GTHE3_COMMON_QPLL1REFCLKSEL_int;
    wire [ 0:0] GTHE3_COMMON_QPLL1RESET_int;
    wire [ 7:0] GTHE3_COMMON_QPLLRSVD1_int;
    wire [ 4:0] GTHE3_COMMON_QPLLRSVD2_int;
    wire [ 4:0] GTHE3_COMMON_QPLLRSVD3_int;
    wire [ 7:0] GTHE3_COMMON_QPLLRSVD4_int;
    wire [ 0:0] GTHE3_COMMON_RCALENB_int;

    // assign each vector either the corresponding tie-off value or the corresponding input port
    if (GTHE3_COMMON_BGBYPASSB_TIE_EN == 1'b1)
      assign GTHE3_COMMON_BGBYPASSB_int = GTHE3_COMMON_BGBYPASSB_VAL;
    else
      assign GTHE3_COMMON_BGBYPASSB_int = GTHE3_COMMON_BGBYPASSB;

    if (GTHE3_COMMON_BGMONITORENB_TIE_EN == 1'b1)
      assign GTHE3_COMMON_BGMONITORENB_int = GTHE3_COMMON_BGMONITORENB_VAL;
    else
      assign GTHE3_COMMON_BGMONITORENB_int = GTHE3_COMMON_BGMONITORENB;

    if (GTHE3_COMMON_BGPDB_TIE_EN == 1'b1)
      assign GTHE3_COMMON_BGPDB_int = GTHE3_COMMON_BGPDB_VAL;
    else
      assign GTHE3_COMMON_BGPDB_int = GTHE3_COMMON_BGPDB;

    if (GTHE3_COMMON_BGRCALOVRD_TIE_EN == 1'b1)
      assign GTHE3_COMMON_BGRCALOVRD_int = GTHE3_COMMON_BGRCALOVRD_VAL;
    else
      assign GTHE3_COMMON_BGRCALOVRD_int = GTHE3_COMMON_BGRCALOVRD;

    if (GTHE3_COMMON_BGRCALOVRDENB_TIE_EN == 1'b1)
      assign GTHE3_COMMON_BGRCALOVRDENB_int = GTHE3_COMMON_BGRCALOVRDENB_VAL;
    else
      assign GTHE3_COMMON_BGRCALOVRDENB_int = GTHE3_COMMON_BGRCALOVRDENB;

    if (GTHE3_COMMON_DRPADDR_TIE_EN == 1'b1)
      assign GTHE3_COMMON_DRPADDR_int = GTHE3_COMMON_DRPADDR_VAL;
    else
      assign GTHE3_COMMON_DRPADDR_int = GTHE3_COMMON_DRPADDR;

    if (GTHE3_COMMON_DRPCLK_TIE_EN == 1'b1)
      assign GTHE3_COMMON_DRPCLK_int = GTHE3_COMMON_DRPCLK_VAL;
    else
      assign GTHE3_COMMON_DRPCLK_int = GTHE3_COMMON_DRPCLK;

    if (GTHE3_COMMON_DRPDI_TIE_EN == 1'b1)
      assign GTHE3_COMMON_DRPDI_int = GTHE3_COMMON_DRPDI_VAL;
    else
      assign GTHE3_COMMON_DRPDI_int = GTHE3_COMMON_DRPDI;

    if (GTHE3_COMMON_DRPEN_TIE_EN == 1'b1)
      assign GTHE3_COMMON_DRPEN_int = GTHE3_COMMON_DRPEN_VAL;
    else
      assign GTHE3_COMMON_DRPEN_int = GTHE3_COMMON_DRPEN;

    if (GTHE3_COMMON_DRPWE_TIE_EN == 1'b1)
      assign GTHE3_COMMON_DRPWE_int = GTHE3_COMMON_DRPWE_VAL;
    else
      assign GTHE3_COMMON_DRPWE_int = GTHE3_COMMON_DRPWE;

    if (GTHE3_COMMON_GTGREFCLK0_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTGREFCLK0_int = GTHE3_COMMON_GTGREFCLK0_VAL;
    else
      assign GTHE3_COMMON_GTGREFCLK0_int = GTHE3_COMMON_GTGREFCLK0;

    if (GTHE3_COMMON_GTGREFCLK1_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTGREFCLK1_int = GTHE3_COMMON_GTGREFCLK1_VAL;
    else
      assign GTHE3_COMMON_GTGREFCLK1_int = GTHE3_COMMON_GTGREFCLK1;

    if (GTHE3_COMMON_GTNORTHREFCLK00_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTNORTHREFCLK00_int = GTHE3_COMMON_GTNORTHREFCLK00_VAL;
    else
      assign GTHE3_COMMON_GTNORTHREFCLK00_int = GTHE3_COMMON_GTNORTHREFCLK00;

    if (GTHE3_COMMON_GTNORTHREFCLK01_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTNORTHREFCLK01_int = GTHE3_COMMON_GTNORTHREFCLK01_VAL;
    else
      assign GTHE3_COMMON_GTNORTHREFCLK01_int = GTHE3_COMMON_GTNORTHREFCLK01;

    if (GTHE3_COMMON_GTNORTHREFCLK10_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTNORTHREFCLK10_int = GTHE3_COMMON_GTNORTHREFCLK10_VAL;
    else
      assign GTHE3_COMMON_GTNORTHREFCLK10_int = GTHE3_COMMON_GTNORTHREFCLK10;

    if (GTHE3_COMMON_GTNORTHREFCLK11_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTNORTHREFCLK11_int = GTHE3_COMMON_GTNORTHREFCLK11_VAL;
    else
      assign GTHE3_COMMON_GTNORTHREFCLK11_int = GTHE3_COMMON_GTNORTHREFCLK11;

    if (GTHE3_COMMON_GTREFCLK00_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTREFCLK00_int = GTHE3_COMMON_GTREFCLK00_VAL;
    else
      assign GTHE3_COMMON_GTREFCLK00_int = GTHE3_COMMON_GTREFCLK00;

    if (GTHE3_COMMON_GTREFCLK01_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTREFCLK01_int = GTHE3_COMMON_GTREFCLK01_VAL;
    else
      assign GTHE3_COMMON_GTREFCLK01_int = GTHE3_COMMON_GTREFCLK01;

    if (GTHE3_COMMON_GTREFCLK10_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTREFCLK10_int = GTHE3_COMMON_GTREFCLK10_VAL;
    else
      assign GTHE3_COMMON_GTREFCLK10_int = GTHE3_COMMON_GTREFCLK10;

    if (GTHE3_COMMON_GTREFCLK11_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTREFCLK11_int = GTHE3_COMMON_GTREFCLK11_VAL;
    else
      assign GTHE3_COMMON_GTREFCLK11_int = GTHE3_COMMON_GTREFCLK11;

    if (GTHE3_COMMON_GTSOUTHREFCLK00_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTSOUTHREFCLK00_int = GTHE3_COMMON_GTSOUTHREFCLK00_VAL;
    else
      assign GTHE3_COMMON_GTSOUTHREFCLK00_int = GTHE3_COMMON_GTSOUTHREFCLK00;

    if (GTHE3_COMMON_GTSOUTHREFCLK01_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTSOUTHREFCLK01_int = GTHE3_COMMON_GTSOUTHREFCLK01_VAL;
    else
      assign GTHE3_COMMON_GTSOUTHREFCLK01_int = GTHE3_COMMON_GTSOUTHREFCLK01;

    if (GTHE3_COMMON_GTSOUTHREFCLK10_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTSOUTHREFCLK10_int = GTHE3_COMMON_GTSOUTHREFCLK10_VAL;
    else
      assign GTHE3_COMMON_GTSOUTHREFCLK10_int = GTHE3_COMMON_GTSOUTHREFCLK10;

    if (GTHE3_COMMON_GTSOUTHREFCLK11_TIE_EN == 1'b1)
      assign GTHE3_COMMON_GTSOUTHREFCLK11_int = GTHE3_COMMON_GTSOUTHREFCLK11_VAL;
    else
      assign GTHE3_COMMON_GTSOUTHREFCLK11_int = GTHE3_COMMON_GTSOUTHREFCLK11;

    if (GTHE3_COMMON_PMARSVD0_TIE_EN == 1'b1)
      assign GTHE3_COMMON_PMARSVD0_int = GTHE3_COMMON_PMARSVD0_VAL;
    else
      assign GTHE3_COMMON_PMARSVD0_int = GTHE3_COMMON_PMARSVD0;

    if (GTHE3_COMMON_PMARSVD1_TIE_EN == 1'b1)
      assign GTHE3_COMMON_PMARSVD1_int = GTHE3_COMMON_PMARSVD1_VAL;
    else
      assign GTHE3_COMMON_PMARSVD1_int = GTHE3_COMMON_PMARSVD1;

    if (GTHE3_COMMON_QPLL0CLKRSVD0_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL0CLKRSVD0_int = GTHE3_COMMON_QPLL0CLKRSVD0_VAL;
    else
      assign GTHE3_COMMON_QPLL0CLKRSVD0_int = GTHE3_COMMON_QPLL0CLKRSVD0;

    if (GTHE3_COMMON_QPLL0CLKRSVD1_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL0CLKRSVD1_int = GTHE3_COMMON_QPLL0CLKRSVD1_VAL;
    else
      assign GTHE3_COMMON_QPLL0CLKRSVD1_int = GTHE3_COMMON_QPLL0CLKRSVD1;

    if (GTHE3_COMMON_QPLL0LOCKDETCLK_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL0LOCKDETCLK_int = GTHE3_COMMON_QPLL0LOCKDETCLK_VAL;
    else
      assign GTHE3_COMMON_QPLL0LOCKDETCLK_int = GTHE3_COMMON_QPLL0LOCKDETCLK;

    if (GTHE3_COMMON_QPLL0LOCKEN_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL0LOCKEN_int = GTHE3_COMMON_QPLL0LOCKEN_VAL;
    else
      assign GTHE3_COMMON_QPLL0LOCKEN_int = GTHE3_COMMON_QPLL0LOCKEN;

    if (GTHE3_COMMON_QPLL0PD_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL0PD_int = GTHE3_COMMON_QPLL0PD_VAL;
    else
      assign GTHE3_COMMON_QPLL0PD_int = GTHE3_COMMON_QPLL0PD;

    if (GTHE3_COMMON_QPLL0REFCLKSEL_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL0REFCLKSEL_int = GTHE3_COMMON_QPLL0REFCLKSEL_VAL;
    else
      assign GTHE3_COMMON_QPLL0REFCLKSEL_int = GTHE3_COMMON_QPLL0REFCLKSEL;

    if (GTHE3_COMMON_QPLL0RESET_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL0RESET_int = GTHE3_COMMON_QPLL0RESET_VAL;
    else
      assign GTHE3_COMMON_QPLL0RESET_int = GTHE3_COMMON_QPLL0RESET;

    if (GTHE3_COMMON_QPLL1CLKRSVD0_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL1CLKRSVD0_int = GTHE3_COMMON_QPLL1CLKRSVD0_VAL;
    else
      assign GTHE3_COMMON_QPLL1CLKRSVD0_int = GTHE3_COMMON_QPLL1CLKRSVD0;

    if (GTHE3_COMMON_QPLL1CLKRSVD1_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL1CLKRSVD1_int = GTHE3_COMMON_QPLL1CLKRSVD1_VAL;
    else
      assign GTHE3_COMMON_QPLL1CLKRSVD1_int = GTHE3_COMMON_QPLL1CLKRSVD1;

    if (GTHE3_COMMON_QPLL1LOCKDETCLK_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL1LOCKDETCLK_int = GTHE3_COMMON_QPLL1LOCKDETCLK_VAL;
    else
      assign GTHE3_COMMON_QPLL1LOCKDETCLK_int = GTHE3_COMMON_QPLL1LOCKDETCLK;

    if (GTHE3_COMMON_QPLL1LOCKEN_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL1LOCKEN_int = GTHE3_COMMON_QPLL1LOCKEN_VAL;
    else
      assign GTHE3_COMMON_QPLL1LOCKEN_int = GTHE3_COMMON_QPLL1LOCKEN;

    if (GTHE3_COMMON_QPLL1PD_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL1PD_int = GTHE3_COMMON_QPLL1PD_VAL;
    else
      assign GTHE3_COMMON_QPLL1PD_int = GTHE3_COMMON_QPLL1PD;

    if (GTHE3_COMMON_QPLL1REFCLKSEL_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL1REFCLKSEL_int = GTHE3_COMMON_QPLL1REFCLKSEL_VAL;
    else
      assign GTHE3_COMMON_QPLL1REFCLKSEL_int = GTHE3_COMMON_QPLL1REFCLKSEL;

    if (GTHE3_COMMON_QPLL1RESET_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLL1RESET_int = GTHE3_COMMON_QPLL1RESET_VAL;
    else
      assign GTHE3_COMMON_QPLL1RESET_int = GTHE3_COMMON_QPLL1RESET;

    if (GTHE3_COMMON_QPLLRSVD1_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLLRSVD1_int = GTHE3_COMMON_QPLLRSVD1_VAL;
    else
      assign GTHE3_COMMON_QPLLRSVD1_int = GTHE3_COMMON_QPLLRSVD1;

    if (GTHE3_COMMON_QPLLRSVD2_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLLRSVD2_int = GTHE3_COMMON_QPLLRSVD2_VAL;
    else
      assign GTHE3_COMMON_QPLLRSVD2_int = GTHE3_COMMON_QPLLRSVD2;

    if (GTHE3_COMMON_QPLLRSVD3_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLLRSVD3_int = GTHE3_COMMON_QPLLRSVD3_VAL;
    else
      assign GTHE3_COMMON_QPLLRSVD3_int = GTHE3_COMMON_QPLLRSVD3;

    if (GTHE3_COMMON_QPLLRSVD4_TIE_EN == 1'b1)
      assign GTHE3_COMMON_QPLLRSVD4_int = GTHE3_COMMON_QPLLRSVD4_VAL;
    else
      assign GTHE3_COMMON_QPLLRSVD4_int = GTHE3_COMMON_QPLLRSVD4;

    if (GTHE3_COMMON_RCALENB_TIE_EN == 1'b1)
      assign GTHE3_COMMON_RCALENB_int = GTHE3_COMMON_RCALENB_VAL;
    else
      assign GTHE3_COMMON_RCALENB_int = GTHE3_COMMON_RCALENB;

    // generate the GTHE3_COMMON primitive instance, mapping parameters and ports
    GTHE3_COMMON #(
      .BIAS_CFG0           (GTHE3_COMMON_BIAS_CFG0          ),
      .BIAS_CFG1           (GTHE3_COMMON_BIAS_CFG1          ),
      .BIAS_CFG2           (GTHE3_COMMON_BIAS_CFG2          ),
      .BIAS_CFG3           (GTHE3_COMMON_BIAS_CFG3          ),
      .BIAS_CFG4           (GTHE3_COMMON_BIAS_CFG4          ),
      .BIAS_CFG_RSVD       (GTHE3_COMMON_BIAS_CFG_RSVD      ),
      .COMMON_CFG0         (GTHE3_COMMON_COMMON_CFG0        ),
      .COMMON_CFG1         (GTHE3_COMMON_COMMON_CFG1        ),
      .POR_CFG             (GTHE3_COMMON_POR_CFG            ),
      .QPLL0_CFG0          (GTHE3_COMMON_QPLL0_CFG0         ),
      .QPLL0_CFG1          (GTHE3_COMMON_QPLL0_CFG1         ),
      .QPLL0_CFG1_G3       (GTHE3_COMMON_QPLL0_CFG1_G3      ),
      .QPLL0_CFG2          (GTHE3_COMMON_QPLL0_CFG2         ),
      .QPLL0_CFG2_G3       (GTHE3_COMMON_QPLL0_CFG2_G3      ),
      .QPLL0_CFG3          (GTHE3_COMMON_QPLL0_CFG3         ),
      .QPLL0_CFG4          (GTHE3_COMMON_QPLL0_CFG4         ),
      .QPLL0_CP            (GTHE3_COMMON_QPLL0_CP           ),
      .QPLL0_CP_G3         (GTHE3_COMMON_QPLL0_CP_G3        ),
      .QPLL0_FBDIV         (GTHE3_COMMON_QPLL0_FBDIV        ),
      .QPLL0_FBDIV_G3      (GTHE3_COMMON_QPLL0_FBDIV_G3     ),
      .QPLL0_INIT_CFG0     (GTHE3_COMMON_QPLL0_INIT_CFG0    ),
      .QPLL0_INIT_CFG1     (GTHE3_COMMON_QPLL0_INIT_CFG1    ),
      .QPLL0_LOCK_CFG      (GTHE3_COMMON_QPLL0_LOCK_CFG     ),
      .QPLL0_LOCK_CFG_G3   (GTHE3_COMMON_QPLL0_LOCK_CFG_G3  ),
      .QPLL0_LPF           (GTHE3_COMMON_QPLL0_LPF          ),
      .QPLL0_LPF_G3        (GTHE3_COMMON_QPLL0_LPF_G3       ),
      .QPLL0_REFCLK_DIV    (GTHE3_COMMON_QPLL0_REFCLK_DIV   ),
      .QPLL0_SDM_CFG0      (GTHE3_COMMON_QPLL0_SDM_CFG0     ),
      .QPLL0_SDM_CFG1      (GTHE3_COMMON_QPLL0_SDM_CFG1     ),
      .QPLL0_SDM_CFG2      (GTHE3_COMMON_QPLL0_SDM_CFG2     ),
      .QPLL1_CFG0          (GTHE3_COMMON_QPLL1_CFG0         ),
      .QPLL1_CFG1          (GTHE3_COMMON_QPLL1_CFG1         ),
      .QPLL1_CFG1_G3       (GTHE3_COMMON_QPLL1_CFG1_G3      ),
      .QPLL1_CFG2          (GTHE3_COMMON_QPLL1_CFG2         ),
      .QPLL1_CFG2_G3       (GTHE3_COMMON_QPLL1_CFG2_G3      ),
      .QPLL1_CFG3          (GTHE3_COMMON_QPLL1_CFG3         ),
      .QPLL1_CFG4          (GTHE3_COMMON_QPLL1_CFG4         ),
      .QPLL1_CP            (GTHE3_COMMON_QPLL1_CP           ),
      .QPLL1_CP_G3         (GTHE3_COMMON_QPLL1_CP_G3        ),
      .QPLL1_FBDIV         (GTHE3_COMMON_QPLL1_FBDIV        ),
      .QPLL1_FBDIV_G3      (GTHE3_COMMON_QPLL1_FBDIV_G3     ),
      .QPLL1_INIT_CFG0     (GTHE3_COMMON_QPLL1_INIT_CFG0    ),
      .QPLL1_INIT_CFG1     (GTHE3_COMMON_QPLL1_INIT_CFG1    ),
      .QPLL1_LOCK_CFG      (GTHE3_COMMON_QPLL1_LOCK_CFG     ),
      .QPLL1_LOCK_CFG_G3   (GTHE3_COMMON_QPLL1_LOCK_CFG_G3  ),
      .QPLL1_LPF           (GTHE3_COMMON_QPLL1_LPF          ),
      .QPLL1_LPF_G3        (GTHE3_COMMON_QPLL1_LPF_G3       ),
      .QPLL1_REFCLK_DIV    (GTHE3_COMMON_QPLL1_REFCLK_DIV   ),
      .QPLL1_SDM_CFG0      (GTHE3_COMMON_QPLL1_SDM_CFG0     ),
      .QPLL1_SDM_CFG1      (GTHE3_COMMON_QPLL1_SDM_CFG1     ),
      .QPLL1_SDM_CFG2      (GTHE3_COMMON_QPLL1_SDM_CFG2     ),
      .RSVD_ATTR0          (GTHE3_COMMON_RSVD_ATTR0         ),
      .RSVD_ATTR1          (GTHE3_COMMON_RSVD_ATTR1         ),
      .RSVD_ATTR2          (GTHE3_COMMON_RSVD_ATTR2         ),
      .RSVD_ATTR3          (GTHE3_COMMON_RSVD_ATTR3         ),
      .RXRECCLKOUT0_SEL    (GTHE3_COMMON_RXRECCLKOUT0_SEL   ),
      .RXRECCLKOUT1_SEL    (GTHE3_COMMON_RXRECCLKOUT1_SEL   ),
      .SARC_EN             (GTHE3_COMMON_SARC_EN            ),
      .SARC_SEL            (GTHE3_COMMON_SARC_SEL           ),
      .SDM0DATA1_0         (GTHE3_COMMON_SDM0DATA1_0        ),
      .SDM0DATA1_1         (GTHE3_COMMON_SDM0DATA1_1        ),
      .SDM0INITSEED0_0     (GTHE3_COMMON_SDM0INITSEED0_0    ),
      .SDM0INITSEED0_1     (GTHE3_COMMON_SDM0INITSEED0_1    ),
      .SDM0_DATA_PIN_SEL   (GTHE3_COMMON_SDM0_DATA_PIN_SEL  ),
      .SDM0_WIDTH_PIN_SEL  (GTHE3_COMMON_SDM0_WIDTH_PIN_SEL ),
      .SDM1DATA1_0         (GTHE3_COMMON_SDM1DATA1_0        ),
      .SDM1DATA1_1         (GTHE3_COMMON_SDM1DATA1_1        ),
      .SDM1INITSEED0_0     (GTHE3_COMMON_SDM1INITSEED0_0    ),
      .SDM1INITSEED0_1     (GTHE3_COMMON_SDM1INITSEED0_1    ),
      .SDM1_DATA_PIN_SEL   (GTHE3_COMMON_SDM1_DATA_PIN_SEL  ),
      .SDM1_WIDTH_PIN_SEL  (GTHE3_COMMON_SDM1_WIDTH_PIN_SEL ),
      .SIM_RESET_SPEEDUP   (GTHE3_COMMON_SIM_RESET_SPEEDUP  ),
      .SIM_VERSION         (GTHE3_COMMON_SIM_VERSION        )
    ) GTHE3_COMMON_PRIM_INST (
      .BGBYPASSB         (GTHE3_COMMON_BGBYPASSB_int         [ 0:0]),
      .BGMONITORENB      (GTHE3_COMMON_BGMONITORENB_int      [ 0:0]),
      .BGPDB             (GTHE3_COMMON_BGPDB_int             [ 0:0]),
      .BGRCALOVRD        (GTHE3_COMMON_BGRCALOVRD_int        [ 4:0]),
      .BGRCALOVRDENB     (GTHE3_COMMON_BGRCALOVRDENB_int     [ 0:0]),
      .DRPADDR           (GTHE3_COMMON_DRPADDR_int           [ 8:0]),
      .DRPCLK            (GTHE3_COMMON_DRPCLK_int            [ 0:0]),
      .DRPDI             (GTHE3_COMMON_DRPDI_int             [15:0]),
      .DRPEN             (GTHE3_COMMON_DRPEN_int             [ 0:0]),
      .DRPWE             (GTHE3_COMMON_DRPWE_int             [ 0:0]),
      .GTGREFCLK0        (GTHE3_COMMON_GTGREFCLK0_int        [ 0:0]),
      .GTGREFCLK1        (GTHE3_COMMON_GTGREFCLK1_int        [ 0:0]),
      .GTNORTHREFCLK00   (GTHE3_COMMON_GTNORTHREFCLK00_int   [ 0:0]),
      .GTNORTHREFCLK01   (GTHE3_COMMON_GTNORTHREFCLK01_int   [ 0:0]),
      .GTNORTHREFCLK10   (GTHE3_COMMON_GTNORTHREFCLK10_int   [ 0:0]),
      .GTNORTHREFCLK11   (GTHE3_COMMON_GTNORTHREFCLK11_int   [ 0:0]),
      .GTREFCLK00        (GTHE3_COMMON_GTREFCLK00_int        [ 0:0]),
      .GTREFCLK01        (GTHE3_COMMON_GTREFCLK01_int        [ 0:0]),
      .GTREFCLK10        (GTHE3_COMMON_GTREFCLK10_int        [ 0:0]),
      .GTREFCLK11        (GTHE3_COMMON_GTREFCLK11_int        [ 0:0]),
      .GTSOUTHREFCLK00   (GTHE3_COMMON_GTSOUTHREFCLK00_int   [ 0:0]),
      .GTSOUTHREFCLK01   (GTHE3_COMMON_GTSOUTHREFCLK01_int   [ 0:0]),
      .GTSOUTHREFCLK10   (GTHE3_COMMON_GTSOUTHREFCLK10_int   [ 0:0]),
      .GTSOUTHREFCLK11   (GTHE3_COMMON_GTSOUTHREFCLK11_int   [ 0:0]),
      .PMARSVD0          (GTHE3_COMMON_PMARSVD0_int          [ 7:0]),
      .PMARSVD1          (GTHE3_COMMON_PMARSVD1_int          [ 7:0]),
      .QPLL0CLKRSVD0     (GTHE3_COMMON_QPLL0CLKRSVD0_int     [ 0:0]),
      .QPLL0CLKRSVD1     (GTHE3_COMMON_QPLL0CLKRSVD1_int     [ 0:0]),
      .QPLL0LOCKDETCLK   (GTHE3_COMMON_QPLL0LOCKDETCLK_int   [ 0:0]),
      .QPLL0LOCKEN       (GTHE3_COMMON_QPLL0LOCKEN_int       [ 0:0]),
      .QPLL0PD           (GTHE3_COMMON_QPLL0PD_int           [ 0:0]),
      .QPLL0REFCLKSEL    (GTHE3_COMMON_QPLL0REFCLKSEL_int    [ 2:0]),
      .QPLL0RESET        (GTHE3_COMMON_QPLL0RESET_int        [ 0:0]),
      .QPLL1CLKRSVD0     (GTHE3_COMMON_QPLL1CLKRSVD0_int     [ 0:0]),
      .QPLL1CLKRSVD1     (GTHE3_COMMON_QPLL1CLKRSVD1_int     [ 0:0]),
      .QPLL1LOCKDETCLK   (GTHE3_COMMON_QPLL1LOCKDETCLK_int   [ 0:0]),
      .QPLL1LOCKEN       (GTHE3_COMMON_QPLL1LOCKEN_int       [ 0:0]),
      .QPLL1PD           (GTHE3_COMMON_QPLL1PD_int           [ 0:0]),
      .QPLL1REFCLKSEL    (GTHE3_COMMON_QPLL1REFCLKSEL_int    [ 2:0]),
      .QPLL1RESET        (GTHE3_COMMON_QPLL1RESET_int        [ 0:0]),
      .QPLLRSVD1         (GTHE3_COMMON_QPLLRSVD1_int         [ 7:0]),
      .QPLLRSVD2         (GTHE3_COMMON_QPLLRSVD2_int         [ 4:0]),
      .QPLLRSVD3         (GTHE3_COMMON_QPLLRSVD3_int         [ 4:0]),
      .QPLLRSVD4         (GTHE3_COMMON_QPLLRSVD4_int         [ 7:0]),
      .RCALENB           (GTHE3_COMMON_RCALENB_int           [ 0:0]),

      .DRPDO             (GTHE3_COMMON_DRPDO                 [15:0]),
      .DRPRDY            (GTHE3_COMMON_DRPRDY                [ 0:0]),
      .PMARSVDOUT0       (GTHE3_COMMON_PMARSVDOUT0           [ 7:0]),
      .PMARSVDOUT1       (GTHE3_COMMON_PMARSVDOUT1           [ 7:0]),
      .QPLL0FBCLKLOST    (GTHE3_COMMON_QPLL0FBCLKLOST        [ 0:0]),
      .QPLL0LOCK         (GTHE3_COMMON_QPLL0LOCK             [ 0:0]),
      .QPLL0OUTCLK       (GTHE3_COMMON_QPLL0OUTCLK           [ 0:0]),
      .QPLL0OUTREFCLK    (GTHE3_COMMON_QPLL0OUTREFCLK        [ 0:0]),
      .QPLL0REFCLKLOST   (GTHE3_COMMON_QPLL0REFCLKLOST       [ 0:0]),
      .QPLL1FBCLKLOST    (GTHE3_COMMON_QPLL1FBCLKLOST        [ 0:0]),
      .QPLL1LOCK         (GTHE3_COMMON_QPLL1LOCK             [ 0:0]),
      .QPLL1OUTCLK       (GTHE3_COMMON_QPLL1OUTCLK           [ 0:0]),
      .QPLL1OUTREFCLK    (GTHE3_COMMON_QPLL1OUTREFCLK        [ 0:0]),
      .QPLL1REFCLKLOST   (GTHE3_COMMON_QPLL1REFCLKLOST       [ 0:0]),
      .QPLLDMONITOR0     (GTHE3_COMMON_QPLLDMONITOR0         [ 7:0]),
      .QPLLDMONITOR1     (GTHE3_COMMON_QPLLDMONITOR1         [ 7:0]),
      .REFCLKOUTMONITOR0 (GTHE3_COMMON_REFCLKOUTMONITOR0     [ 0:0]),
      .REFCLKOUTMONITOR1 (GTHE3_COMMON_REFCLKOUTMONITOR1     [ 0:0]),
      .RXRECCLK0_SEL     (GTHE3_COMMON_RXRECCLK0_SEL         [ 1:0]),
      .RXRECCLK1_SEL     (GTHE3_COMMON_RXRECCLK1_SEL         [ 1:0])

    );

  end
  endgenerate


endmodule
