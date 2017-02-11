//------------------------------------------------------------------------------
// File       : SaltUltraScaleCore_lvds_transceiver.v
// Author     : Xilinx
//------------------------------------------------------------------------------
// (c) Copyright 2006 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES. 

//
//
//------------------------------------------------------------------------------
// Description:  This module makes the GPIO SGMII logic look like a hardened SERDES.
//  Making it easier to hook into the existing GEMAC+PCS/PMA cores
//------------------------------------------------------------------------------


`timescale 1 ps / 1 ps

module SaltUltraScaleCore_lvds_transceiver_ser8 (
// Transceiver Transmitter Interface (synchronous to clk125m)
input wire          txchardispmode,
input wire          txchardispval,
input wire          txcharisk,
input wire  [ 7:0]  txdata,
output wire         txbuferr,

// // Transceiver Receiver Interface (synchronous to clk125m)
// output reg          rxchariscomma,
// output wire         rxcharisk,
// output wire [ 7:0]  rxdata,
// output wire         rxdisperr,
// output wire         rxnotintable,
// output wire         rxrundisp,
// output wire         rxbuferr,

// clocks and reset
input wire          clk625,
input wire          clk125,
input wire          clk312,
input wire          reset, // CLK125
input wire          soft_tx_reset,
// input wire          soft_rx_reset,
// Serial input wire and output wire differential pairs
output wire         pin_sgmii_txn,
output wire         pin_sgmii_txp
// input wire          idelay_rdy,
// input wire          pin_sgmii_rxn,
// input wire          pin_sgmii_rxp
);


// wire [9:0] rx_data_10b;
wire [9:0] tx_data_10b;
// wire       rxchariscomma_i;
wire       tx_rst;
// wire       rx_rst;

assign tx_rst = reset  || soft_tx_reset;
// assign rx_rst = reset  || soft_rx_reset ;

///////////////////////////////////////////////////////////
//Receiver logic 
///////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////

// //adding a delay on rxchariscomma to compensate for delay in 8b10b decode
// always @(posedge clk125) begin
// rxchariscomma  <= rxchariscomma_i;
// end


 // SaltUltraScaleCore_serdes_1_to_10_ser8  # (
	// .REF_FREQ		(625.0),			// 625 = 1.25 Gbps DDR
	// .BIT_TIME		(800))				// 800 = 1.25 Gbps
 // serdes_1_to_10_ser8_i (
    // .datain_p           (pin_sgmii_rxp)  ,
    // .datain_n           (pin_sgmii_rxn)  ,
    // .rxclk              (clk625)  ,
    // .rxclk_div4         (clk312)  ,
    // .rxclk_div10        (clk125),
    // .idelay_rdy         (idelay_rdy)  ,
    // .reset              (rx_rst)  ,
    // .rx_data            ()  ,//left open
    // .comma              (rxchariscomma_i)  ,
    // .al_rx_data         (rx_data_10b)  ,
    // .debug_in           (7'b0010000)  ,
    // .debug              (),    //left open
    // .dummy_out          (),
    // .results            (),
    // .m_delay_1hot       ()
    // );



  // // 8b/10b Decoder
  // SaltUltraScaleCore_decode_8b10b_lut_base #
  // (
    // .C_HAS_CODE_ERR        (1),
    // .C_HAS_DISP_ERR        (1),
    // .C_HAS_DISP_IN         (0),
    // .C_HAS_ND              (0),
    // .C_HAS_SYM_DISP        (0),
    // .C_HAS_RUN_DISP        (1),
    // .C_SINIT_DOUT          (8'b0),
    // .C_SINIT_KOUT          (0),
    // .C_SINIT_RUN_DISP      (0)

  // ) decode_8b10b (
    // .clk                   (clk125),
    // .din                   (rx_data_10b),
    // .dout                  (rxdata),
    // .kout                  (rxcharisk),

    // .ce                    (1'b1),
    // .disp_in               (1'b0),
    // .sinit                 (1'b0),
    // .code_err              (rxnotintable),
    // .disp_err              (rxdisperr),
    // .nd                    (),
    // .run_disp              (rxrundisp),
    // .sym_disp              ()
  // );



///////////////////////////////////////////////////////////
//Transmitter logic 
///////////////////////////////////////////////////////////
// data is given to serdes block after encoding 


// 8b/10b from XAPP 1122
SaltUltraScaleCore_encode_8b10b_lut_base #
  (
    .C_HAS_DISP_IN     (1),
    .C_HAS_FORCE_CODE  (0),
    .C_FORCE_CODE_DISP (1),
    .C_HAS_ND          (0),
    .C_HAS_KERR        (0)

  ) encode_8b10b (
    .din               (txdata),  // 8 bit
    .kin               (txcharisk),
    .clk               (clk125),  // 125 MHz
    .dout              (tx_data_10b),  // 10 bit
    .ce                (1'b1),
    .force_code        (1'b0),
    .force_disp        (txchardispmode),
    .disp_in           (txchardispval),
    .disp_out          (),
    .kerr              (),
    .nd                ()
  );     

  SaltUltraScaleCore_serdes_10_to_1_ser8 serdes_10_to_1_ser8_i (
    .txclk      (clk625) ,
    .reset      (tx_rst) ,
    .system_clk (clk125) ,
    .inter_clk  (clk312) ,
    .datain     (tx_data_10b) ,
    .dataout_p  (pin_sgmii_txp) ,
    .dataout_n  (pin_sgmii_txn)  
    ) ;
assign txbuferr = 1'b0; // There is no TX buffer
// assign rxbuferr = 1'b0; // There is no TX buffer


endmodule




