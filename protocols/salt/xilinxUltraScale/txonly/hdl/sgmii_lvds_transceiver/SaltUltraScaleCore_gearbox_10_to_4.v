//////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2012 Xilinx, Inc.
// This design is confidential and proprietary of Xilinx, All Rights Reserved.
//////////////////////////////////////////////////////////////////////////////
//   ____  ____
//  /   /\/   /
// /___/  \  /   Vendor: Xilinx
// \   \   \/    Version: 1.0
//  \   \        Filename: SaltUltraScaleCore_gearbox_10_to_4.v
//  /   /        Date Last Modified:  March 25th 2013
// /___/   /\    Date Created: March 25th 2013
// \   \  /  \
//  \___\/\___\
// 
//Device: 	Virtex 6
//Purpose:  	multiple 10 to 4 bit gearbox
//
//Reference:	
//    
//Revision History:
//    Rev 1.0 - First created (nicks)
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

`timescale 1ps/1ps

module SaltUltraScaleCore_gearbox_10_to_4 (input_clock, output_clock, datain, reset, dataout) ;

parameter integer 		D = 8 ;   		// Parameter to set the number of data lines  

input				input_clock ;		// high speed clock input
input				output_clock ;		// low speed clock input
input		[D*10-1:0]	datain ;		// data inputs
input				reset ;			// Reset line
output	reg	[D*4-1:0]	dataout ;		// data outputs
					
reg	[3:0]		write_addr ;			
wire	[3:0]		read_addra ;			
reg	[3:0]		read_addrb ;			
reg			read_enable ;	
reg			read_enable_dom_ch ;	
wire	[D*12-1:0]	ram_out ; 			
wire			local_reset ;	
reg	[5:0]		r_state ;		
wire	[D*2-1:0]	dummya ;			
wire	[D*2-1:0]	dummyb ;			

genvar i ;

//always @ (posedge input_clock) begin				// generate local sync reset
//	if (reset == 1'b1) begin
//		local_reset <= 1'b1 ;
//	end else begin
//		local_reset <= 1'b0 ;
//	end
//end 

	
  SaltUltraScaleCore_reset_sync reset_sync_output_clk (
     .clk       (output_clock),
     .reset_in  (reset),
     .reset_out (local_reset)
  );

always @ (posedge input_clock) begin				// Gearbox input - 10 bit data at input clock frequency
	if (reset == 1'b1) begin
		write_addr <= 4'h0 ;
		read_enable <= 1'b0 ;
	end 
	else begin
		write_addr <= write_addr + 4'h1 ;
		if (write_addr == 4'h3) begin
			read_enable <= 1'b1 ;
		end
	end
end

always @ (posedge output_clock) begin	
	read_enable_dom_ch <= read_enable ;
end

always @ (posedge output_clock) begin				// Gearbox output - 4 bit data at output clock frequency
	read_addrb <= r_state[5:2] + 1 ;	
	if (local_reset == 1'b1 || read_enable_dom_ch == 1'b0) begin
		r_state <= 6'h00 ;
	end
	else begin
		case (r_state)
		6'h02    : begin r_state <= 6'h04 ; end
		6'h05    : begin r_state <= 6'h08 ; end 
		6'h0A    : begin r_state <= 6'h0C ; end 
		6'h0D    : begin r_state <= 6'h10 ; end 
		6'h12    : begin r_state <= 6'h14 ; end
		6'h15    : begin r_state <= 6'h18 ; end 
		6'h1A    : begin r_state <= 6'h1C ; end 
		6'h1D    : begin r_state <= 6'h20 ; end
		6'h22    : begin r_state <= 6'h24 ; end
		6'h25    : begin r_state <= 6'h28 ; end 
		6'h2A    : begin r_state <= 6'h2C ; end 
		6'h2D    : begin r_state <= 6'h30 ; end
		6'h32    : begin r_state <= 6'h34 ; end
		6'h35    : begin r_state <= 6'h38 ; end 
		6'h3A    : begin r_state <= 6'h3C ; end 
		6'h3D    : begin r_state <= 6'h00 ; end
		default  : begin r_state <= r_state + 6'h01 ; end 
		endcase 
	end
end

generate
for (i = 0 ; i <= D-1 ; i = i+1)
begin : loop0

always @ (posedge output_clock) begin
	case (r_state[2:0])
		3'h0    : begin dataout[4*i+3:4*i] <= ram_out[12*i+3 :12*i+0] ; end
		3'h1    : begin dataout[4*i+3:4*i] <= ram_out[12*i+7 :12*i+4] ; end
		3'h2    : begin dataout[4*i+3:4*i] <= ram_out[12*i+11:12*i+8] ; end
		3'h4    : begin dataout[4*i+3:4*i] <= ram_out[12*i+5 :12*i+2] ; end 
		default : begin dataout[4*i+3:4*i] <= ram_out[12*i+9 :12*i+6] ; end
	endcase 
end 
end
endgenerate 
			     	
// Data gearboxes

assign read_addra = r_state[5:2] ;

generate
for (i = 0 ; i <= D-1 ; i = i+1)
begin : loop2

RAM32M ram_inst0 ( 
	.DOA		(ram_out[12*i+1:12*i+0]), 
	.DOB		(ram_out[12*i+3:12*i+2]),
	.DOC    	(ram_out[12*i+5:12*i+4]), 
	.DOD    	(dummya[2*i+1:2*i]),
	.ADDRA		({1'b0, read_addra}), 
	.ADDRB		({1'b0, read_addra}), 
	.ADDRC  	({1'b0, read_addra}), 
	.ADDRD  	({1'b0, write_addr}),
	.DIA		(datain[10*i+1:10*i+0]), 
	.DIB		(datain[10*i+3:10*i+2]),
	.DIC    	(datain[10*i+5:10*i+4]),
	.DID    	(dummya[2*i+1:2*i]),
	.WE 		(1'b1), 
	.WCLK		(input_clock));

RAM32M ram_inst1 ( 
	.DOA		(ram_out[12*i+7:12*i+6]), 
	.DOB		(ram_out[12*i+9:12*i+8]),
	.DOC    	(ram_out[12*i+11:12*i+10]), 
	.DOD    	(dummyb[2*i+1:2*i]),
	.ADDRA		({1'b0, read_addra}), 
	.ADDRB		({1'b0, read_addra}), 
	.ADDRC  	({1'b0, read_addrb}), 
	.ADDRD  	({1'b0, write_addr}),
	.DIA		(datain[10*i+7:10*i+6]), 
	.DIB		(datain[10*i+9:10*i+8]),
	.DIC    	(datain[10*i+1:10*i+0]),
	.DID    	(dummyb[2*i+1:2*i]),
	.WE 		(1'b1), 
	.WCLK		(input_clock));
	
end
endgenerate 

endmodule
