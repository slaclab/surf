
//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2012 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
//////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /   Vendor: Xilinx
// \   \   \/    Version: 1.0
//  \   \        Filename: SaltUltraScaleCore_serdes_10_to_1_ser8.vhd
//  /   /        Date Last Modified: September 6th 2013
// /___/   /\    Date Created: December 6th 2012
// \   \  /  \
//  \___\/\___\
// 
//Device: 	Ultrascale
//Purpose:  	10 to 1 output serialiser
//
//Reference:	
//    
//Revision History:
//    Rev 1.0 - First created (nicks)
//
//////////////////////////////////////////////////////////////////////////////
//
//  Disclaimer: 
//
//		This disclaimer is not a license and does not grant any rights to the materials 
//              distributed herewith. Except as otherwise provided in a valid license issued to you 
//              by Xilinx, and to the maximum extent permitted by applicable law: 
//              (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, 
//              AND XILINX HEREBY DISCLAIMS ALL WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, 
//              INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR 
//              FITNESS FOR ANY PARTICULAR PURPOSE; and (2) Xilinx shall not be liable (whether in contract 
//              or tort, including negligence, or under any other theory of liability) for any loss or damage 
//              of any kind or nature related to, arising under or in connection with these materials, 
//              including for any direct, or any indirect, special, incidental, or consequential loss 
//              or damage (including loss of data, profits, goodwill, or any type of loss or damage suffered 
//              as a result of any action brought by a third party) even if such damage or loss was 
//              reasonably foreseeable or Xilinx had been advised of the possibility of the same.
//
//  Critical Applications:
//
//		Xilinx products are not designed or intended to be fail-safe, or for use in any application 
//		requiring fail-safe performance, such as life-support or safety devices or systems, 
//		Class III medical devices, nuclear facilities, applications related to the deployment of airbags,
//		or any other applications that could lead to death, personal injury, or severe property or 
//		environmental damage (individually and collectively, "Critical Applications"). Customer assumes 
//		the sole risk and liability of any use of Xilinx products in Critical Applications, subject only 
//		to applicable laws and regulations governing limitations on product liability.
//
//  THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
//
//////////////////////////////////////////////////////////////////////////////
`timescale 1 ps/1 ps
module SaltUltraScaleCore_serdes_10_to_1_ser8 (txclk, reset, system_clk, inter_clk, datain, dataout_p, dataout_n) ;

                                     	                                   	
input			txclk ;				// DDR transmitter clock network at line rate divided by 2 = 625 MHz for SGMII
input			reset ;				// Asynchronous active high reset line
input			inter_clk ;			// Clock at line rate divided by 4 = 312.5 MHz for SGMII
input			system_clk ;			// Clock at system rate, ie line rate divided by 10 = 125 MHz for SGMII
input		[9:0]	datain ;			// 10-bit Data for output
output			dataout_p ;			// differential output data
output			dataout_n ;			// differential output data

	
wire 	[3:0]		dataint ;	
wire 			tx_clk_out ;
wire			local_reset ;

//always @ (posedge inter_clk or posedge reset) begin
//if (reset == 1'b1) begin
//	local_reset <= 1'b1 ;
//end
//else begin
//	local_reset <= 1'b0 ;
//end
//end
	
  SaltUltraScaleCore_reset_sync reset_sync_inter_clk (
     .clk       (system_clk),
     .reset_in  (reset),
     .reset_out (local_reset)
  );

OBUFDS io_data_out(
	.O    		(dataout_p),
	.OB       	(dataout_n),
	.I         	(tx_data_out));
	
SaltUltraScaleCore_gearbox_10_to_4  # (						// translate 10 bit data to 4 bit data
	.D 			(1))
gb0 (
	.input_clock		(system_clk),
	.output_clock		(inter_clk),
	.datain			(datain),
	.reset			(local_reset),
	.dataout		(dataint)) ;

OSERDESE3 #(							// output serialiser
    	.DATA_WIDTH 		(4),
    	.INIT 			(1'b0),
    	.IS_CLKDIV_INVERTED 	(1'b0),
    	.IS_CLK_INVERTED 	(1'b0),
    	.IS_RST_INVERTED 	(1'b0))
oserdes_m(
    	.OQ                  	(tx_data_out),
    	.T_OUT               	(),
    	.CLK                 	(txclk),
    	.CLKDIV              	(inter_clk),
    	.D                   	({4'h0, dataint}),
    	.RST                 	(local_reset),
    	.T                   	(1'b0));				
		
endmodule
